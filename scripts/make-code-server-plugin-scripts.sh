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
        VARS+="
    if [[ -d \"$source_dir\" ]]; then
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

init_copy_input_cmds() {
    COPY_INPUT_CMDS="pids=\"\"; \\"
    for x in ${@}; do
        COPY_INPUT_CMDS+="
        bash -l <<< \"$(copy_inputs_cmd $x)\" & \\
        pids=\"\${pids:+\$pids }\$!\";";
    done
    echo "$COPY_INPUT_CMDS
        wait \${pids}";
}

copy_output_cmd() {
    name="$(get_env_var_name $1)";
    echo "copy-output-util --project=\"$1\" --src=\"\$${name}_CPP_SOURCE_DIR\" --bin=\"\$${name}_CPP_BINARY_DIR\"";
}

make_cpp_script() {
    name="$1"
    repo="$2"
    cmds="$3"
    deps="${@:4}"
    cat << EOF > "$PLUGINS_DIR/$repo-cpp/$name"
#! /usr/bin/env bash
set -Eeo pipefail;
cd "\$(dirname "\$(realpath "\$0")")";
if [[ -d "\$HOME/rapids/$repo" ]]; then

    tmp_env_file="\$(mktemp)";
    touch "\$HOME/rapids/.env";
    cp "\$HOME/rapids/.env" "\$tmp_env_file";

    on_exit() {
        ERRCODE="\$?";
        rm -f "\$tmp_env_file" >/dev/null 2>&1 || true;
        exit "\$ERRCODE";
    }

    trap on_exit ERR EXIT HUP INT QUIT TERM STOP PWR;

    set -a && . "\$tmp_env_file" && set +a;

    $(dir_envvars ${deps} $repo)

    $(init_volumes ${deps} $repo)

    docker run \\
        --rm -it --runtime nvidia \\
        --env-file "\$tmp_env_file" \\
        \${volumes} \\
        ${BUILD_IMAGE} \\
        bash -c '$cmds' _ "\${@}";
fi
EOF

    chmod +x "$PLUGINS_DIR/$repo-cpp/$name"
}

make_clean_cpp_script() {
    echo "generating \`clean-$1-cpp\` script";
    make_cpp_script clean $1 "
        clean-$1-cpp;";
}

make_build_cpp_script() {
    echo "generating \`build-$1-cpp\` script";
    make_cpp_script build $1 "
        $(init_copy_input_cmds ${@:2} $1); \\
        build-$1-cpp \"\${@}\"; \\
        $(copy_output_cmd $1);" \
        "${@:2}";
}

make_compile_cpp_script() {
    echo "generating \`compile-$1-cpp\` script";
    make_cpp_script compile $1 "
        $(init_copy_input_cmds ${@:2} $1); \\
        compile-$1-cpp \"\${@}\"; \\
        $(copy_output_cmd $1);" \
        "${@:2}";
}

make_configure_cpp_script() {
    echo "generating \`configure-$1-cpp\` script";
    make_cpp_script configure $1 "
        $(init_copy_input_cmds ${@:2} $1); \\
        configure-$1-cpp \"\${@}\"; \\
        $(copy_output_cmd $1);" \
        "${@:2}";
}

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
