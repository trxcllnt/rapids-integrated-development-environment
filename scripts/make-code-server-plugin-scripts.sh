#! /usr/bin/env bash

set -Eeo pipefail

cd $(dirname "$(realpath "$0")")/..;

PLUGINS_DIR="compose/code-server/plugins"
BUILD_IMAGE="pauletaylor/rapids-ide:cpp-builder-cuda${CUDA_VERSION:-11.6.0}-ubuntu20.04"

get_env_var_name() {
    name="$(echo $1 | tr '[:lower:]' '[:upper:]')";
    echo "${name//\-/_}";
}

dir_envvars() {
    VARS=""
    for x in ${@}; do
        name="$(get_env_var_name $x)";
        source_dir="\$HOME/rapids/$x";
        cpp_source_dir="\$(cpp-source-dir-util --project=$x)";
        cpp_binary_dir="\$(cpp-binary-dir-util --project=$x)";
        VARS="${VARS:+$VARS\n    }if [[ -d \"$source_dir\" ]]; then
        echo \"${name}_SOURCE_DIR=$source_dir\" >> \"\$tmp_env_file\";
        echo \"${name}_CPP_SOURCE_DIR=$cpp_source_dir\" >> \"\$tmp_env_file\";
        echo \"${name}_CPP_BINARY_DIR=$cpp_binary_dir\" >> \"\$tmp_env_file\";
    fi\
"
    done
    echo -e "$VARS"
}

init_volumes() {
    VOLUMES="volumes=\"\";"
    for x in ${@}; do
        volume=
        if [[ $x == $1 ]]; then
            volume="-v \$HOME/rapids/$x:\$HOME/rapids/$x "
        else
            volume="-v \$HOME/rapids/$x:\$HOME/rapids/$x:ro "
        fi
        VOLUMES+="
    if [[ -d \"\$HOME/rapids/$x\" ]]; then volumes+=\"$volume\"; fi"
    done
    echo -e "$VOLUMES"
}

copy_inputs_cmd() {
    name="$(get_env_var_name $1)";
    echo "copy-inputs-util --project=\\\"$1\\\" --src=\\\"\\\$${name}_SOURCE_DIR\\\" --bin=\\\"\\\$${name}_CPP_BINARY_DIR\\\"";
}

copy_input_cmds() {
    COPY_INPUT_CMDS="pids=\"\"; \\";
    for x in ${@}; do
        COPY_INPUT_CMDS+="
        bash -l <<< \"$(copy_inputs_cmd $x)\" & \\
        pids=\"\${pids:+\$pids }\$!\";";
    done
    echo "$COPY_INPUT_CMDS
        wait \${pids}";
}

print_path_rewrites() {
    PRINT_PATH_REWRITE_CMDS="";
    for x in ${@}; do
        name="$(get_env_var_name $x)";
        inner_src_dir="/opt/rapids/$x";
        outer_src_dir="\$HOME/rapids/$x";
        outer_cpp_src_dir="\$${name}_CPP_SOURCE_DIR";
        outer_cpp_bin_dir="\$${name}_CPP_BINARY_DIR";
        outer_cpp_bin_dir_relative="\$(realpath -m --relative-to=\"\$${name}_CPP_SOURCE_DIR\" \"\$${name}_CPP_BINARY_DIR\")";
        inner_cpp_src_dir="\$(realpath -m \"$inner_src_dir/\$(realpath -m --relative-to=\"\$${name}_SOURCE_DIR\" \"\$${name}_CPP_SOURCE_DIR\")\")";
        inner_cpp_bin_dir="$inner_src_dir/build";
        PRINT_PATH_REWRITE_CMDS="${PRINT_PATH_REWRITE_CMDS:+$PRINT_PATH_REWRITE_CMDS
        }echo \"sed -r \\\"s@$inner_cpp_bin_dir@$outer_cpp_bin_dir@g\\\"\";
        echo \"sed -r \\\"s@$inner_cpp_src_dir@$outer_cpp_src_dir@g\\\"\";
        echo \"sed -r \\\"s@ build/@ $outer_cpp_bin_dir_relative/@g\\\"\";"
    done
    echo "$PRINT_PATH_REWRITE_CMDS"
}

rewrite_output_paths() {
    REWRITE_OUTPUT_CMDS="";
    for x in ${@}; do
        name="$(get_env_var_name $x)";
        inner_src_dir="/opt/rapids/$x";
        outer_src_dir="\$HOME/rapids/$x";
        outer_cpp_src_dir="\$${name}_CPP_SOURCE_DIR";
        outer_cpp_bin_dir="\$${name}_CPP_BINARY_DIR";
        outer_cpp_bin_dir_relative="\$(realpath -m --relative-to=\"\$${name}_CPP_SOURCE_DIR\" \"\$${name}_CPP_BINARY_DIR\")";
        inner_cpp_src_dir="\$(realpath -m \"$inner_src_dir/\$(realpath -m --relative-to=\"\$${name}_SOURCE_DIR\" \"\$${name}_CPP_SOURCE_DIR\")\")";
        inner_cpp_bin_dir="$inner_src_dir/build";
        REWRITE_OUTPUT_CMDS="${REWRITE_OUTPUT_CMDS:+$REWRITE_OUTPUT_CMDS \\
          | }sed -r \"s@$inner_cpp_bin_dir@$outer_cpp_bin_dir@g\" \\
          | sed -r \"s@$inner_cpp_src_dir@$outer_cpp_src_dir@g\" \\
          | sed -r \"s@ build/@ $outer_cpp_bin_dir_relative/@g\""
    done
    echo "$REWRITE_OUTPUT_CMDS"
}

copy_output_cmd() {
    name="$(get_env_var_name $1)";
    echo "copy-output-util --project=\"$1\" --src=\"\$${name}_CPP_SOURCE_DIR\" --bin=\"\$${name}_CPP_BINARY_DIR\"";
}

make_cpp_script() {
    (
        name="$1";
        repo="$2";
        cmds="$3";
        deps="${@:4}";
        mkdir -p "$PLUGINS_DIR/$repo/cpp";
        cat << EOF > "$PLUGINS_DIR/$repo/cpp/$name"
#! /usr/bin/env bash
set -Eeo pipefail;
cd "\$(dirname "\$(realpath "\$0")")";
if [[ -d "\$HOME/rapids/$repo" ]]; then

    tmp_env_file="\$(mktemp)";
    touch "\$HOME/rapids/.config/cpp.env" "\$tmp_env_file";

    cat "\$HOME/rapids/.config/cpp.env" >> "\$tmp_env_file";

    if [ -n \${BUILD_TYPE:-} ]; then
        echo "BUILD_TYPE=\$BUILD_TYPE" >> "\$tmp_env_file";
        sed -ir "s/^BUILD_TYPE=\w+\\$/BUILD_TYPE=\$BUILD_TYPE/g" "\$tmp_env_file";
    fi
    if [ -n \${BUILD_TESTS:-} ]; then
        echo "BUILD_TESTS=\$BUILD_TESTS" >> "\$tmp_env_file";
        sed -ir "s/^BUILD_TESTS=\w+\\$/BUILD_TESTS=\$BUILD_TESTS/g" "\$tmp_env_file";
    fi
    if [ -n \${BUILD_BENCH:-} ]; then
        echo "BUILD_BENCH=\$BUILD_BENCH" >> "\$tmp_env_file";
        sed -ir "s/^BUILD_BENCH=\w+\\$/BUILD_BENCH=\$BUILD_BENCH/g" "\$tmp_env_file";
    fi

    on_exit() {
        ERRCODE="\$?";
        rm -f "\$tmp_env_file" >/dev/null 2>&1 || true;
        exit "\$ERRCODE";
    }

    trap on_exit ERR EXIT HUP INT QUIT TERM STOP PWR;

    (
    set -a && source "\$tmp_env_file" && set +a;

    $(dir_envvars $repo ${deps})

    $(init_volumes $repo ${deps})

    set -x;
    docker run \\
        --rm -it --runtime nvidia \\
        --env-file "\$tmp_env_file" \\
        --name "$name-$repo-cpp-\$(basename "\$tmp_env_file")" \\
        \${volumes} \\
        ${BUILD_IMAGE} \\
        bash -c '$cmds' _ "\${@}";
    )
fi
EOF

        chmod +x "$PLUGINS_DIR/$repo/cpp/$name"
    )
}

make_clone_script() {
    echo "generating \`clone-$1\` script";
    (
        repo="$1";
        deps="${@:2}";
        mkdir -p "$PLUGINS_DIR/$repo";
        cat << EOF > "$PLUGINS_DIR/$repo/clone"
#! /usr/bin/env bash
set -Eeo pipefail;
cd "\$(dirname "\$(realpath "\$0")")";

GHHOSTS="\$HOME/.config/gh/hosts.yml";

if [[ ! -f "\$GHHOSTS" ]]; then gh auth login; fi

GH_USER="\$(grep --color=never 'user:' "\$GHHOSTS" | cut -d ':' -f2 | tr -d '[:space:]')";

if [[ -n "\$GH_USER" && ! -d "\$HOME/rapids/$repo" ]]; then
$(for dep in $deps; do echo "    clone-$dep;"; done)
    REPO="\$GH_USER/$repo";
    FORK="\$(gh repo list \$GH_USER --fork --json name --jq '. | map(select(.name == "$repo")) | map(.name)[]')";
    if [[ ! "\$FORK" ]]; then
        ORIGIN_URL="github.com/\$GH_USER/$repo";
        UPSTREAM_URL="github.com/rapidsai/$repo";
        while true; do
            read -p "\\\`\$UPSTREAM_URL\\\` not found.
Fork \\\`$UPSTREAM_URL\\\` into \\\`\$ORIGIN_URL\\\` now (y/n)? " CHOICE </dev/tty
            case \$CHOICE in
                [Nn]* ) REPO="rapidsai/$repo"; break;;
                [Yy]* ) gh repo fork rapidsai/$repo --clone=false; break;;
                * ) echo "Please answer 'y' or 'n'";;
            esac
        done;
    fi
    gh repo clone \$REPO "\$HOME/rapids/$repo";
fi
EOF

        chmod +x "$PLUGINS_DIR/$repo/clone"
    )
}

make_clean_cpp_script() {
    echo "generating \`clean-$1-cpp\` script";
    make_cpp_script clean $1 "
        clean-$1-cpp;";
}

make_build_cpp_script() {
    echo "generating \`build-$1-cpp\` script";
    (
        cat << EOF > "$PLUGINS_DIR/$1/cpp/build"
#! /usr/bin/env bash
set -Eeo pipefail;
cd "\$(dirname "\$(realpath "\$0")")";

configure-$1-cpp && compile-$1-cpp;
EOF
        chmod +x "$PLUGINS_DIR/$1/cpp/build"
    )
}

make_compile_cpp_script() {
    echo "generating \`compile-$1-cpp\` script";
    make_cpp_script compile $1 "
        $(copy_input_cmds ${@:2} $1); \\
        compile-$1-cpp \"\${@}\" 2>&1 \\
          | $(rewrite_output_paths ${@:2} $1); \\
        $(copy_output_cmd $1);" \
        "${@:2}";
}

make_configure_cpp_script() {
    echo "generating \`configure-$1-cpp\` script";
    make_cpp_script configure $1 "
        $(copy_input_cmds ${@:2} $1); \\
        configure-$1-cpp \"\${@}\" 2>&1 \\
          | $(rewrite_output_paths ${@:2} $1); \\
        $(copy_output_cmd $1);" \
        "${@:2}";
}

make_clone_script rmm;
make_clone_script raft rmm;
make_clone_script cudf rmm;
make_clone_script cumlprims_mg rmm raft;
make_clone_script cuml rmm raft cumlprims_mg;
make_clone_script cugraph-ops rmm raft;
make_clone_script cugraph rmm raft cugraph-ops;
make_clone_script cuspatial rmm cudf;

make_clean_cpp_script rmm;
make_clean_cpp_script raft;
make_clean_cpp_script cudf;
make_clean_cpp_script cumlprims_mg;
make_clean_cpp_script cuml;
make_clean_cpp_script cugraph-ops;
make_clean_cpp_script cugraph;
make_clean_cpp_script cuspatial;

make_build_cpp_script rmm;
make_build_cpp_script raft rmm;
make_build_cpp_script cudf rmm;
make_build_cpp_script cumlprims_mg rmm raft;
make_build_cpp_script cuml rmm raft cumlprims_mg;
make_build_cpp_script cugraph-ops rmm raft;
make_build_cpp_script cugraph rmm raft cugraph-ops;
make_build_cpp_script cuspatial rmm cudf;

make_compile_cpp_script rmm;
make_compile_cpp_script raft rmm;
make_compile_cpp_script cudf rmm;
make_compile_cpp_script cumlprims_mg rmm raft;
make_compile_cpp_script cuml rmm raft cumlprims_mg;
make_compile_cpp_script cugraph-ops rmm raft;
make_compile_cpp_script cugraph rmm raft cugraph-ops;
make_compile_cpp_script cuspatial rmm cudf;

make_configure_cpp_script rmm;
make_configure_cpp_script raft rmm;
make_configure_cpp_script cudf rmm;
make_configure_cpp_script cumlprims_mg rmm raft;
make_configure_cpp_script cuml rmm raft cumlprims_mg;
make_configure_cpp_script cugraph-ops rmm raft;
make_configure_cpp_script cugraph rmm raft cugraph-ops;
make_configure_cpp_script cuspatial rmm cudf;
