#!/usr/bin/env python3
import sys
import subprocess
import re
import os
import tempfile
import shutil
import json
import glob
import pickle

# thanks stackoverflow: https://stackoverflow.com/questions/3503719/emulating-bash-source-in-python
# (w/ modifications)
def source(file_to_source_path, include_unexported_variables=True):
    """works much like bash source: runs the (bash) script given, any stderr and stdout are passed through,
    any environment variables set are captured and this script's environment updated
    (by default includes those set with export and not)"""
    source = '%ssource %s' % ("set -a && " if include_unexported_variables else "", file_to_source_path)
    
    temp_filename = tempfile.mktemp()

    dump = '/usr/bin/env python3 -c "import os, pickle; pickle.dump(dict(os.environ), open(\'%s\', \'wb\'))"' % (temp_filename)
    process = subprocess.Popen(['/bin/bash', '-c', '%s && %s' % (source, dump)])
    process.wait()
    if process.returncode != 0:
        sys.stderr.write("Source failed. Script: " + os.path.basename(file_to_source_path) + ", return code: " + str(process.returncode) + "\n")
        exit(1)
            
 
    set_environ = pickle.load(open(temp_filename, "rb"))
    for key in set_environ:
        os.environ[key] = set_environ[key]

def exec(cmd): 
  """A simple utility to run a command with subprocess and return the result from stdout."""
  try:
      res = subprocess.check_output(cmd, shell = True)
  except subprocess.CalledProcessError as error:
      sys.stderr.write("Called process failed. Error: \n")
      sys.stderr.write(str(error))
      sys.stderr.write("\n")
      exit(1)
  return res.strip().decode("utf-8")


# allow use of ${red}This is an error${white} in sourced scripts
os.environ["black"] = exec("tput setaf 0")
os.environ["red"] = exec("tput setaf 1")
os.environ["green"] = exec("tput setaf 2")
os.environ["yellow"] = exec("tput setaf 3")
os.environ["blue"] = exec("tput setaf 4")
os.environ["magenta"] = exec("tput setaf 5")
os.environ["cyan"] = exec("tput setaf 6")
os.environ["white"] = exec("tput setaf 7")


def source_files_glob(pathpattern):
    """Source files matching file glob, e.g. /some/path/*.sh"""
    files = glob.glob(pathpattern)
    for filename in files:
        source(filename)






def usage():
  sys.stderr.write("Helm kush allows embedding of kustomizations and bash-based templating within charts.\n")
  sys.stderr.write("See https://github.com/oneilsh/helm-kush for details.\n\n")
  sys.stderr.write("Usage: helm kush <install|upgrade|template|<script_name>> [NAME] [CHART] [FLAGS] [--kush-interpolate] ...\n")


#########################
## Arg parsing - mostly we'll be passing along to helm pulling out a few items
#########################

# drop the script path 
args = sys.argv[1:]

# parse command, check for unsupported things
helm_command = args[0]

if re.search("(help)|(--help)|(-h)", " ".join(args)):
    usage()
    exit(1)

if "--generate-name" in args:
    sys.stderr.write("Sorry, kush does not support --generate-name currently, explicit release name required or default RELEASE-NAME will be used.\n")
    exit(1)


# parse out the release name and chart name from the confusing way helm allows them to be specified (release name optional, all positional)
chart = ""
release_name = "RELEASE-NAME"
params = []

# if they didn't provide a name, the third entry will either start with - (be an option) or won't exist
if len(args) < 3 or args[2].startswith("-"):
    chart = args[1]
    params = args[2:]
else:
    release_name = args[1]
    chart = args[2]
    params = args[3:]


# determine if this is a dry run (template for --dry-run added)
dry_run = False
if helm_command == "template" or "--dry-run" in params:
    dry_run = True

# determine if we're allowing interpolation
interpolate = False
if "--kush-interpolate" in params:
    interpolate = True
    params.remove("--kush-interpolate")


# parse out the files specified by --values or -f
user_values_files = []
other_params = []

i = 0
while i < len(params):
    param_i = params[i]
    if param_i == "--values" or param_i == "-f":
        user_values_files.append(params[i+1])
        i = i + 2
    else:
        other_params.append(param_i)
        i = i + 1



###################################
## done parsing args, begin operational stuff
###################################

helm_bin = os.environ["HELM_BIN"]

chart_name = exec(helm_bin + " show chart " + chart + " | grep '^name: ' | sed -r 's/^name: //' ")

with tempfile.TemporaryDirectory() as tempdir:
    chart_dir = os.path.join(tempdir, chart_name)
 
    # if they're working with a directory chart, we want a copy, otherwise we want to pull and untar
    if os.path.isdir(chart):
        shutil.copytree(chart, chart_dir)
    else:
        exec(helm_bin + " pull --untar --untardir=" + tempdir + " " + chart) 
 
 
    # create a folder for their --values files
    user_values_dir = os.path.join(chart_dir, "user_values_files")
    os.mkdir(user_values_dir)
 
    # copy their user values files there
    for filename in user_values_files:
        try:
            shutil.copy(filename, user_values_dir)
        except OSError as error:
            sys.stderr.write("Kush unable to find values file " + filename + ", does it exist? Error:\n")
            sys.stderr.write(str(error))
            sys.stderr.write("\n")
            exit(1)
 
    # sanity check 
    if not os.path.isdir(os.path.join(chart_dir, "kush")):
        sys.stderr.write("Helm kush is intented to be run on charts with a kush/ subdirectory; this doesn't appear to be a kush-enabled chart. \n")
        exit(1)
    

    # variables needed by the post-renderer
    os.environ["WORK_DIR"] = os.path.join(chart_dir, "kush")
    os.environ["RELEASE_NAME"] = release_name

    # extra vars that might come in handy in sourced scripts
    os.environ["CHART"] = chart
    os.environ["CHARTNAME"] = chart_name


    # if we're interpolating, run esh interpolation on all .yaml files and all files in the kush directory
    os.environ["LC_ALL"] = "C"  # hush up an awk warning thrown by esh
    esh_bin = os.path.join(os.environ["HELM_PLUGIN_DIR"], "bin", "esh")
   
    # they want to run a supported helm command
    if re.search("(install)|(upgrade)|(template)", helm_command):

        # we only want to run .pre.sh scripts if they are running a 
        if interpolate: 
            # execute .pre.sh files in the kush dir (prior to interpolation),
            # updating the environment if they export anything
            source_files_glob(os.path.join(chart_dir, "kush", "*.pre.sh"))
            
            
            files = exec("find " + chart_dir + " -type f -name '*.yaml'").strip().split("\n") # -exec sh -c '" + esh_bin + " {} > {}.esh_temp && mv {}.esh_temp {}' \;")
            files.extend(exec("find " + os.path.join(chart_dir, "kush") + " -type f").strip().split("\n")) # -exec sh -c '" + esh_bin + " {} > {}.esh_temp && mv {}.esh_temp {}' \;")
            for filename in files:
                if filename != "":
                    exec(esh_bin + " " + filename + " > " + filename + ".esh_temp && mv " + filename + ".esh_temp " + filename)
    
        # ok! now we can run their helm command with the post-rendere
        
        post_renderer = os.path.join(os.environ["HELM_PLUGIN_DIR"], "bin", "post-renderer.sh")
        quoted_extra_args = " ".join(['"' + arg + '"' for arg in other_params])
        quoted_user_values = " ".join(['--values ' + '"' + os.path.join(user_values_dir, os.path.basename(arg)) + '"' for arg in user_values_files])
    
        result = exec(helm_bin + " " + helm_command + " " + release_name + " " + chart_dir + " --post-renderer=" + post_renderer + " " + quoted_extra_args + " " + quoted_user_values)
        print(result)
        
        if interpolate:
            # execute .post.sh files in the kush dir
            source_files_glob(os.path.join(chart_dir, "kush", "*.post.sh"))

    # they want to run a kush/somescript
    elif os.path.isfile(os.path.join(chart_dir, "kush", helm_command)):
        source_args = " ".join(["'" + arg + "'" for arg in args[1:]])     # the first element will be the script name itself
        source(os.path.join(chart_dir, "kush", helm_command) + " " + source_args) 

    else:
        sys.stderr.write("Error: " + os.path.join(chart_name, "kush", helm_command) + " not found.\n")
        exit(1)



