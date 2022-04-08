#! /usr/bin/env bash

set -Eeo pipefail

cd $(dirname "$(realpath "$0")")/..;

PLUGINS_DIR="compose/code-server/plugins"
BUILD_IMAGE="pauletaylor/rapids-ide:cpp-builder-cuda${CUDA_VERSION:-11.6.0}-ubuntu20.04"
REPOS="rmm raft cudf cumlprims_mg cuml cugraph-ops cugraph cuspatial"

get_env_var_name() {
    name="$(echo $1 | tr '[:lower:]' '[:upper:]')";
    echo "${name//\-/_}";
}

dir_envvars() {
    VARS=""
    for x in ${REPOS}; do
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
    for x in ${REPOS}; do
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
    # echo "copy-inputs-util --project=$1 --src=\\\$${name}_SOURCE_DIR --bin=\\\$${name}_CPP_BINARY_DIR";
    # echo "copy-inputs-util --project=\"$1\" --src=\"\$${name}_SOURCE_DIR\" --bin=\"\$${name}_CPP_BINARY_DIR\"";
    # echo "copy-inputs-util --project=\\\"$1\\\" --src=\\\"\$${name}_SOURCE_DIR\\\" --bin=\\\"\$${name}_CPP_BINARY_DIR\\\"";
    echo "copy-inputs-util --project=\\\"$1\\\" --src=\\\"\\\$${name}_SOURCE_DIR\\\" --bin=\\\"\\\$${name}_CPP_BINARY_DIR\\\"";
}

init_copy_input_cmds() {
    # COPY_INPUT_CMDS="copy_input_cmds=\"\";"
    # for x in ${REPOS}; do
    #     COPY_INPUT_CMDS+="
    # if [[ -d \"\$HOME/rapids/$x\" ]]; then
    #     copy_input_cmds=\"\${copy_input_cmds:+\$copy_input_cmds && }$(copy_inputs_cmd $x)\";
    # fi"
    # done
    # echo -e "$COPY_INPUT_CMDS"
    COPY_INPUT_CMDS="pids=\"\"; \\"
    for x in ${REPOS}; do
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
    # echo "copy-output-util --project=\\\"$1\\\" --src=\\\"\\\$${name}_CPP_SOURCE_DIR\\\" --bin=\\\"\\\$${name}_CPP_BINARY_DIR\\\"";
}

make_script() {
    cat << EOF > "$PLUGINS_DIR/$1-cpp/$2"
#! /usr/bin/env bash
set -Eeo pipefail;
cd "\$(dirname "\$(realpath "\$0")")";
if [[ -d "\$HOME/rapids/$1" ]]; then

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

    cpp_bin_dir="\$(cpp-binary-dir-util --project=$1)";
    cpp_src_dir="\$(cpp-source-dir-util --project=$1)";
    $(dir_envvars)

    $(init_volumes $1)

    docker run \\
        --rm -it --runtime nvidia \\
        --env-file "\$tmp_env_file" \\
        \${volumes} \\
        ${BUILD_IMAGE} \\
        bash -c '${@:3}';

    if [[ -f "\$cpp_bin_dir/compile_commands.json" ]]; then
        ln -sf "\$cpp_bin_dir/compile_commands.json" "\$cpp_src_dir/compile_commands.json";
    fi
fi
EOF

    chmod +x "$PLUGINS_DIR/$1-cpp/$2"
}

make_clean_script() {
    make_script $1 clean "
        clean-$1-cpp;";
}

make_build_script() {
    make_script $1 build "
        $(init_copy_input_cmds); \\
        build-$1-cpp; \\
        $(copy_output_cmd $1);";
}

make_compile_script() {
    make_script $1 compile "
        $(init_copy_input_cmds); \\
        compile-$1-cpp; \\
        $(copy_output_cmd $1);";
}

make_configure_script() {
    make_script $1 configure "
        $(init_copy_input_cmds); \\
        configure-$1-cpp; \\
        $(copy_output_cmd $1);";
}

for x in ${REPOS}; do
    echo "clean-$x-cpp";
    make_clean_script "$x";
done

for x in ${REPOS}; do
    echo "build-$x-cpp";
    make_build_script "$x";
done

for x in ${REPOS}; do
    echo "compile-$x-cpp";
    make_compile_script "$x";
done

for x in ${REPOS}; do
    echo "configure-$x-cpp";
    make_configure_script "$x";
done
