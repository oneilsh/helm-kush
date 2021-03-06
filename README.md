Table of Contents
=================

   * [helm-kush (kustomize-sh)](#helm-kush-kustomize-sh)
      * [Overview](#overview)
      * [Known Bugs / TODOs](#known-bugs--todos)
      * [Changelog](#changelog)
      * [Prerequisites and Installation](#prerequisites-and-installation)
      * [Basic Usage: Chart Install](#basic-usage-chart-install)
      * [Chart Authoring w/ Kustomization](#chart-authoring-w-kustomization)
      * [Chart Authoring w/ Interpolation](#chart-authoring-w-interpolation)
         * [Pre- and post- scripts](#pre--and-post--scripts)
         * [Custom --values](#custom---values)
         * [Summary](#summary)

Created by [gh-md-toc](https://github.com/ekalinin/github-markdown-toc)


# helm-kush (kustomize-sh)

Helm plugin for in-chart kustomizations and optional bash interpolation the embedded [esh](https://github.com/jirutka/esh) template engine. 

Note: this software bypasses many of the safety features in helm's design. Interpolation in particular
allows--encourages even--helm charts to run *arbitrary code*. It's meant primarily for internally 
developed charts. 

## Overview

Kush (from kustomize-sh) is a simple `helm` plugin allowing [kustomize](https://kustomize.io/) directories to be 
stored within Helm [charts](https://helm.sh/docs/chart_template_guide/getting_started/) and used for post-rendering. 

Kustomize (or `kubectl kustomize`) when used for [post-rendering](https://helm.sh/docs/topics/advanced/#post-rendering) of Helm charts solves a common problem: third-party 
charts included as dependencies frequently don't expose as much [flexibility as we'd like](https://testingclouds.wordpress.com/2018/07/20/844/) 
via `values.yaml`. Helm3's `--post-renderer` isn't batteries-included though; the user must write a (usually simple) 
post-rending script and maintain kustomize resources independently. 

At the same time, various yaml-based tools (including Helm and kustomize) 
[deliberately eschew](https://kubernetes-sigs.github.io/kustomize/faq/eschewedfeatures/#build-time-side-effects-from-cli-args-or-env-variables) 
all but basic templating functions, preferring to keep configuration 'simple' (*cough*) and deterministic. Tools like [ytt](https://get-ytt.io/)
and [dhall](https://github.com/dhall-lang) bring sophisticated scripting abilities to yaml, but are complex domain-specific
languages with limited ability to leverage external tooling. 

Kush includes an option to interpolate inline-bash from included kustomize resources, chart yaml files, and user-supplied yaml files with an embedded
[esh](https://github.com/jirutka/esh) template engine, and it supports sourcing chart-embedded scripts during deployment. 
This is less secure than ytt and dhall (because it runs arbitrary code hosted
in charts as part of the deployment process), but very flexible and accessible. Interpolation is not enabled by default, and must be enabled with
`--kush-interpolate`.

## Known Bugs / TODOs

Helm post-rendering is known not to work with resources that utilize helm hooks, see [https://github.com/helm/helm/issues/7891](https://github.com/helm/helm/issues/7891) for details.

Using `--generate-name` is not supported, and parsing of release name and chart currently assumes these are
the first options, as in `helm kush template my-release-name chart-repo/chart ...`. 

## Changelog

v0.4.0 - Switched to python for main plugin script for robustness. Removed custom values.yaml embedded scripting, but added support for esh templating in custom values.yaml.

v0.3.0 - Initial version.

## Prerequisites and Installation

Helm 3.X and kubectl version 1.14 or above, python3.X in path.  

Install with: 

```
helm plugin install https://github.com/oneilsh/helm-kush
```

## Basic Usage: Chart Install

Kush-enabled charts will contain a `kush` directory with kustomize resources for post-rendering. Helm kush 
currently only supports post-rendering for `install`, `upgrade`, and `template`. (Charts withough `kush` directories
are treated as normally.)

Examples:

First, add this repo as a helm chart repo and see the example chart:

```
helm repo add kush-examples https://oneilsh.github.io/helm-kush/
helm repo update
helm search repo kush-examples
```

Some example runs:

This example uses kustomize to modify the deployment containers' environment variables:

```
helm kush template myrelease kush-examples/basic-example
```

This works with additional `--values` specifications or other helm flags (but note that `--values` entries do *not* override 
anything in the charts' kustomizations, because `--values` is incorporated during chart rendering 
before kustomize is applied).

This example requires the addition of `--kush-interpolate` to allow interpolation scripts etc. to run. 

```
helm kush template myrelease kush-examples/interpolation-example --kush-interpolate
```

This also works with `--values` (only via local file, not URL like standard helm) and provides opportunities for scripting and interpolation there as well (more below).

```
wget https://raw.githubusercontent.com/oneilsh/helm-kush/master/kush-examples/interpolation-example/custom-values.yaml
helm kush template myrelease kush-examples/interpolation-example --kush-interpolate --values custom-values.yaml
```



## Chart Authoring w/ Kustomization

Let's start by creating a basic chart with `helm create`, and remove the `templates/tests/test-connection.yaml` since it uses a helm hook 
and these are currently [buggy](https://github.com/helm/helm/issues/7891) with `--post-renderer`.

```
helm create basic-example
rm basic-example/templates/tests/test-connection.yaml
```

Next create a `kush` directory to hold kustomization files. 

```
mkdir basic-example/kush
```

We'll add a `kustomization.yaml` file (required name), which must have at least `helm-template-output.yaml` listed as a resource (the result
of running `helm template` on the base chart); we'll also modify the deployment so we'll specify a patch with `patch-deployment.yaml`:

**`basic-example/kush/kustomization.yaml`**:
```
resources:
    - helm-template-output.yaml
patchesStrategicMerge:
    - patch-deployment.yaml
```

For the deployment patch, we'll suppose that our container accepts initial admin credentials via environment variable, but these
aren't exposed for configuration by the chart (and we'll suppose we're working with a dependency chart). 

Note that when a chart specifies that the release name is part of the resource name (a common practice with helm charts),
we use `RELEASE-NAME` as a placeholder. 

**`basic-example/kush/patch-deployment.yaml`**:
```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: RELEASE-NAME-basic-example
spec:
  template:
    spec:
      replicaCount: 1
      containers:
        - name: basic-example
          env:
            - name: ADMIN_PASSWORD
              value: temporary-pass
            - name: ADMIN_USERNAME
              value: admin
```

And that's it; `basic-example` can now be deployed with `helm kush` without the need for forking the upstream chart (though we didn't include
it as a dependency, we might have), and we get kustomize resources 'bundled' with the chart. This can be handy in cases where kustomize 
is used with a custom chart but the files need to match the chart version. 

## Chart Authoring w/ Interpolation

Start with a similar setup as above:

```
helm create interpolation-example
rm interpolation-example/templates/tests/test-connection.yaml
mkdir interpolation-example/kush
```

And the same `kustomization.yaml` file.

**`interpolation-example/kush/kustomization.yaml`**:
```
resources:
    - helm-template-output.yaml
patchesStrategicMerge:
    - patch-deployment.yaml
```

The difference is in `patch-deployment.yaml`, where we fill the values from environment variables 
(or any bash-evaluatable expression, e.g. `$(expr 8000 + $RANDOM % 1000)` for a random number between 8000 and 8999).
Interpolation is handled by [esh](https://github.com/jirutka/esh/blob/master/esh), see the documentation there for details.

**`interpolation-example/kush/patch-deployment.yaml`**:
```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: RELEASE-NAME-interpolation-example
spec:
  template:
    spec:
      containers:
        - name: interpolation-example
          env:
            - name: ADMIN_PASSWORD
              value: <%= $ADMIN_INIT_PASSWORD %>
            - name: ADMIN_USERNAME
              value: <%= $ADMIN_INIT_USERNAME %>
```

Now we can run the chart with these variables set:

```
ADMIN_INIT_PASSWORD=passwd ADMIN_INIT_USERNAME=oneils helm kush template myrelease interpolation-example --kush-interpolate
```

The relevant section of output:

```
    spec:
      containers:
      - env:
        - name: ADMIN_PASSWORD
          value: passwd
        - name: ADMIN_USERNAME
          value: oneils
        image: nginx:1.16.0
        imagePullPolicy: IfNotPresent
        livenessProbe:
          httpGet:
            path: /
            port: http
        name: interpolation-example
        ports:
        - containerPort: 80
```

Why would one use environment variables when `--set` is made for this purpose? You likely wouldn't. But then, `--set` can't be used with
a post-renderer, and you may not want to keep individual kustomize yaml for every deployment. 

If your chart requires certain pre-reqs to properly build (as in this case), these checks can be built into a `.pre.sh` script (below).

### Pre- and post- scripts

Inline interpolation is one thing, but we may want to run more complex scripts before or after the templating, kustomization, and
interpolation. This is enabled by adding `.pre.sh` and/or `.post.sh` files to the `kush` directory; `.pre.sh` files are run 
(sourced, actually, so they can setup variables etc.) prior to templating, kustomization, and interpolation, and `.pre.sh` files are run after.

Let's use a `.pre.sh` file to default the username to the running user (`$USER`) and password to a randomly generated passphrase, if those
variables are not already set. (Note that both exported and un-exported variables are available to later scripts and interpolation.) 

**`interpolation-example/kush/00_admin_pw.pre.sh`**:
```
if [ "$ADMIN_INIT_USERNAME" == "" ]; then
  ADMIN_INIT_USERNAME=$USER
fi

if [ "$ADMIN_INIT_PASSWORD" == "" ]; then
  # sed here fixes windows-style newline
  ADMIN_INIT_PASSWORD=$(curl --silent "https://makemeapassword.ligos.net/api/v1/passphrase/plain?whenUp=StartOfWord&sp=F&pc=1&wc=2&sp=y&maxCh=20" | sed -r 's/\r//g')
fi
```

As mentioned above, if requirements must be in place for proper interpolation a `.pre.sh` file can be used to check. (But as these are run
as the first step, it's difficult to determine if requirements may be satisfied in later steps.)

**`interpolation-example/kush/01_preflight_check.pre.sh`**:
```
if [ $(echo $ADMIN_INIT_USERNAME | wc -c) -gt 14 ]; then
  echo "${red}Error: \$ADMIN_INIT_USERNAME cannot be longer than 14 characters (got $ADMIN_INIT_USERNAME). ${white}" 1>&2
  exit 1
fi
```

Color variables (black, red, green, yellow, blue, magenta, cyan, white (default)) are available for basic output styling.

Since each deployment will produce different output, it may make sense to also add a line like 

```
echo "Your username/password are $ADMIN_INIT_USERNAME/$ADMIN_INIT_PASSWORD, write them down!" >> $CHART_DIR/templates/NOTES.txt
```

which will modify the (temporary) to-be-deployed copy of the chart's `NOTES.txt` to print additional usage information. However, if these values
change again during the templating/kustomization/interpolation steps (and this is possible) this information may not be accurate. 

So, we'll just print the information directly in a `.post.sh` script:

**`interpolation-example/kush/00_adjust_notes.post.sh`**:
```
echo "${yellow}Your username/password are $ADMIN_INIT_USERNAME/$ADMIN_INIT_PASSWORD, write them down!${white}"
```

In the above we've used `$CHART_DIR` (which is a temporary working copy of the chart) and some color variables; here are the ones available
for scripts and interpolations:

* `$CHART_DIR` - location of working chart copy (`$CHART_DIR/user_values_files` will contain copies of files specified by `--values`; they are interpolated at the interpolation step, see summary below)
* `$RELEASE_NAME` - the given release name (holds `RELEASE-NAME` if not given, using `--generate-name` is not supported)
* `$CHART` - the chart as given, e.g. `kush-examples/interpolation-example` (from repo) or `https://oneilsh.github.io/helm-kush/interpolation-example-0.1.0.tgz` (direct URL) or just `interpolation-example` (local path)
* `$CHART_NAME` - the name of the chart
* `$DRY_RUN` - set to `"True"` if running `helm kush template` or anything with `--dry-run`.

Other environment variables are provided by the helm plugin architecture, see the list [here](https://helm.sh/docs/topics/plugins/#environment-variables). 

### Custom --values

All of the features thus far live in the chart's `kush` directory and are baked into the chart, mostly to provide flexibility when 
relying on third-party dependency charts or complex pre- or post-processing with a familiar bash API. 

It's also possible to do interpolation in values files included with `--values` (or the shorthand `-f`); for example
we may want to set the number of replicas from a variable (defaulting to 3 if unset, or 1 in the release name ends with `dev`):

**`custom-values.yaml`**:
```
<% if echo $RELEASE_NAME | grep -Eqs 'dev$'; then %>
replicaCount: 1
<% else %>
replicaCount: <%= ${REPLICAS:-3} %>
<% fi %>
```


### Summary

In summary, the order of operations is:

1. `.pre.sh` files in the chart `kush` directory are processed
2. Chart `.yaml` files and files specified by `--values` are templated with `esh` (in a temporary copy of the chart). This includes all `.yaml` files (including those in `templates` and other directories).
3. The chart is rendered and processed with `kustomization.yaml`
4. `.post.sh` files in the chart `kush` directory are processed

Steps 1, 2, and 4 are only applied with `--kush-interpolate` is given as a flag to helm. 


## Bonus: did you know --values files can be made executable? 

The trick is to use `#!/usr/bin/env -S` option (which requires a recent version of `env`) 
to use multi-parameter options for the interpreter.

When using `env`, the `#!` will always have the name of the containing file appended sent to the
interpreter (which will be treated as the last argument by `env -S`), so just make
sure to leave the last specified parameter as `--values` when templating, installing, or upgrading.
For delete there's no real use for the final parameter (the containing file), but the string 
containing the filename can be used for the delete description.

```
#!/usr/bin/env -S helm template dev-registry stable/docker-registry --values 
# execute this yaml file to template it!

# install: 
#!/usr/bin/env -S helm install dev-registry stable/docker-registry --namespace dev-projects --values 

# upgrade: 
#!/usr/bin/env -S helm upgrade dev-registry --install stable/docker registry --namespace dev-projects --values

# delete:
#!/usr/bin/env -S helm delete dev-registry --namespace dev-projects --description 

resources:
  limits:
    cpu: 100m
    memory: 256Mi
  requests:
    cpu: 100m
    memory: 256Mi
persistence:
  accessMode: 'ReadWriteOnce'
  enabled: true
  size: 60Gi

```

This works fine with `helm kush` as well, of course :)
