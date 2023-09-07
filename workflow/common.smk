
def get_targets():
    """final output files are of the form: {dataset}/{app}/{root_dir}/sub-{subject}/ses-{session}"""
    targets = list()
    for dataset in config["datasets"].keys():
        for app in config["apps"].keys():
            for root in config["apps"][app]["retain_subj_dirs_from"]:
                targets.extend(
                    bids_intersect[dataset].expand(
                        Path(dataset)
                        / "derivatives"
                        / Path(app)
                        / Path(bids(root=root, **subj_wildcards[dataset])).parent
                    )
                )

    return targets


def get_session_filter(wildcards):
    input_to_filter = config["apps"][wildcards.app]["input_to_filter"]
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
        for dep in config["apps"][app]["depends_on"]:
            for root_dir in config["apps"][dep]["retain_subj_dirs_from"]:
                inputs.append(
                    Path(dataset)
                    / "derivatives"
                    / dep
                    / Path(bids(root=root_dir, **subj_wildcards[dataset])).parent
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
    return config["apps"][app].get("shadow", config.get("shadow", None))


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
            f"-p --force-output --cores {threads} --pybidsdb-dir {input.bids}/.pybids"
        )
    else:
        return ""



def get_dryrun_echo(wildcards):
    """adds echo before the run cmd if the dryrun is enabled"""
    if config["apps"][wildcards.app].get("dryrun",config["defaults"].get("dryrun",False)):
        return "echo"
    else:
        return ""

def get_dryrun_touch(wildcards,output):
    """ touch/mkdir outputs for dryrun"""
    if config["apps"][wildcards.app].get("dryrun",config["defaults"].get("dryrun",False)):

        cmds=[]
        for f in output.files:
            cmds.append(f"touch {f}")
        for d in output.dirs:
            cmds.append(f"mkdir -p {d}")
        return " && "+" && ".join(cmds)
    else:
        return ""

