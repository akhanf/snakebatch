def get_targets_by_app_dataset(app, dataset):
    targets = list()

    # app overrided wildcards (eg to loop over subject only even if session exists):
    wildcards = {
        wc: f"{{{wc}}}"
        for wc in config["apps"][app].get("wildcards", subj_wildcards[dataset].keys())
    }

    for root in config["apps"][app]["retain_subj_dirs_from"]:
        targets.extend(
            bids_intersect[dataset].expand(
                Path(dataset)
                / "derivatives"
                / Path(app)
                / Path(bids(root=root, **wildcards)).parent
            )
        )

    return targets


def get_targets_by_dataset(dataset):
    """final output files are of the form: {dataset}/{app}/{root_dir}/sub-{subject}/ses-{session}"""
    targets = list()
    for app in config["apps"].keys():
        targets.extend(get_targets_by_app_dataset(app, dataset))
    return targets


def get_targets_by_app(app):
    """final output files are of the form: {dataset}/{app}/{root_dir}/sub-{subject}/ses-{session}"""
    targets = list()
    for dataset in config["datasets"].keys():
        targets.extend(get_targets_by_app_dataset(app, dataset))
    return targets


def get_targets():
    """final output files are of the form: {dataset}/{app}/{root_dir}/sub-{subject}/ses-{session}"""
    targets = list()
    for dataset in config["datasets"].keys():
        targets.extend(get_targets_by_dataset(dataset))
    return targets


def get_session_filter(wildcards):
    input_to_filter = config["apps"][wildcards.app].get("input_to_filter", None)
    if isinstance(input_to_filter, list):
        if "session" in wildcards._names:
            return " ".join(
                [f"--filter-{i} session={wildcards.session}" for i in input_to_filter]
            )
        else:
            return ""

    else:
        if "session" in wildcards._names:
            return f"--filter-{input_to_filter} session={wildcards.session}"
        else:
            return ""


def get_bids_input(wildcards, input):
    if "bids_dir" in config["apps"][wildcards.app]:
        return config["apps"][wildcards.app]["bids_dir"].format(**wildcards)
    else:
        return input.bids


rule get_snakebids_app:
    params:
        url=lambda wildcards: config["apps"][wildcards.app]["url"],
        tag=lambda wildcards: config["apps"][wildcards.app]["tag"],
    output:
        repo=directory("resources/repos/{app}"),
    localrule: True
    shell:
        "git clone {params.url} -b {params.tag} {output.repo}"


def get_sb_container(app):
    if "container" in config["apps"][app].keys():
        return {"container": f"resources/containers/{app}.sif"}
    else:
        return {}


def get_sb_repo(app):
    if "url" in config["apps"][app].keys():
        return {"repo": "resources/repos/{app}"}
    else:
        return {}


def get_dependencies(app, dataset):
    if "depends_on" in config["apps"][app].keys():
        inputs = []

        # app overrided wildcards (eg to loop over subject only even if session exists):
        wildcards = {
            wc: f"{{{wc}}}"
            for wc in config["apps"][app].get(
                "wildcards", subj_wildcards[dataset].keys()
            )
        }

        for dep in config["apps"][app]["depends_on"]:
            for root_dir in config["apps"][dep]["retain_subj_dirs_from"]:
                inputs.append(
                    Path(dataset)
                    / "derivatives"
                    / dep
                    / Path(bids(root=root_dir, **wildcards)).parent
                )

        return {"depends": inputs}
    else:
        return {}


def get_sb_singularity_opts(wildcards):
    if "url" in config["apps"][wildcards.app].keys():
        singularity_prefix = config["apps"][wildcards.app].get(
            "singularity_prefix", config["defaults"].get("singularity_prefix", None)
        )  # look in apps, then defaults
        if singularity_prefix == None:
            return "--use-singularity"
        else:
            return f"--use-singularity --singularity-prefix {singularity_prefix}"
    else:
        return ""


def get_shadow(app):
    return config["apps"][app].get("shadow", config["defaults"].get("shadow", None))

def get_runscript(app):
    # runscript could be inside the container, in the cloned repo, or in the local filesystem
    #  - if it is in the container then it doesn't have to be in inputs, but otherwise it does (for shadow to symlink it)
    if "runscript" in config["apps"][app].keys():
        if "url" in config["apps"][app].keys():
            return {"runscript": f"resources/repos/{app}/{config['apps'][app]['runscript']}" }
        else:
            if Path(config["apps"][app]["runscript"]).exists():
                return {"runscript": config["apps"][app]["runscript"]}
    else: 
        return {}

def get_run_cmd(wildcards, input):
    if "url" in config["apps"][wildcards.app].keys():
        return (
            f"python3 resources/repos/{wildcards.app}/{config['apps'][wildcards.app]['runscript']}",
        )
    elif "container" in config["apps"][wildcards.app].keys():
        singularity_opts = config["apps"][wildcards.app].get("singularity_opts", "")

        if "runscript" in config["apps"][wildcards.app].keys():
            return f"singularity exec {singularity_opts} {input.container} {input.runscript}"
        else:
            return f"singularity run {singularity_opts} {input.container}"
    else:
        return ""


def get_snakebids_opts(wildcards, input, threads):
    if config["apps"][wildcards.app].get("snakebids", False):
        return (
            f"-p --force-output --cores {threads} " #--pybidsdb-dir {input.bids}/.pybids"
        )
    else:
        return ""


def get_threads(wildcards):
    return config["apps"][wildcards.app]["resources"].get(
        "cores", config["defaults"]["resources"]["cores"]
    )


def get_log_file(app, dataset):
    wildcards = {
        wc: f"{{{wc}}}"
        for wc in config["apps"][app].get("wildcards", subj_wildcards[dataset].keys())
    }
    return bids(root="logs/{dataset}_{app}", **wildcards)
