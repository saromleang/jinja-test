from jinja2 import Environment, FileSystemLoader

context={
    "install.info": {
        "build_path": "/Users/sarom/GAMESS-Development/dir.git.dev",
        "ddi_comm": "sockets",
        "fortran": "oneapi-ifort",
        "fpe": "",
        "gms_debug_flag": "None",
        "gms_debug_link_flag": "None",
        "ifort_verno": "2022",
        "libcchem": "false",
        "libcchem_libs": "-ldl",
        "libxc": "false",
        "mathlib": "mkl",
        "mathlib_path": "/opt/intel/oneapi/mkl/2022.0.0/lib",
        "mdi": "false",
        "mkl_verno": "12",
        "mpi_lib": None,
        "msucc": "false",
        "nbo": "false",
        "neo": "false",
        "omp_num_threads": 6,
        "omp_stacksize": "1G",
        "openmp": "false",
        "path": "/Users/sarom/GAMESS-Development/dir.git.dev",
        "phi": "none",
        "shmtype": "sysv",
        "system_target": "generic",
        "target": "linux64",
        "tinker": "false",
        "vb2000": "false",
        "verachem": "false",
        "xlf_path": None,
        "xmvb": "false"
    },
    "rungms": {
        "rungms": False,
        "system_target": "generic",
        "scheduler": "cobalt",
        "pwd": True,
        "executable": "fortran",
        "shell": "csh",
        "target": "sockets",
        "include_gddi": True,
        "include_remd": True,
        "include_myipcrm": True,
        "include_binary_info": True,
        "include_launch_header": True
    }
}

TEMPLATE_ENVIRONMENT = Environment(
    autoescape=False,
    loader=FileSystemLoader('templates/'),
    trim_blocks=True,
    lstrip_blocks=True)

filename = "rungms-dev.csh"

with open(filename, 'w') as f:
    rungms_dev = TEMPLATE_ENVIRONMENT.get_template("rungms-dev.template").render(context=context)
    f.write(rungms_dev)
    f.write("\n")