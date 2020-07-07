# helm-kush (kustomize-sh)

Helm plugin for in-chart kustomizations and optional bash interpolation. 

Note: this is early-stage software with security and reproducibility considerations. 

## Overview

Kush (from kustomize-sh) is a simple `helm` plugin allowing [kustomize](https://kustomize.io/) directories to be 
stored within Helm [charts](https://helm.sh/docs/chart_template_guide/getting_started/) and used for post-rendering. 

Kustomize (or `kubectl kustomize`) when used for post-rendering of Helm charts solves a common problem: third-party 
charts included as dependencies frequently don't expose as much [flexibility as we'd like](https://testingclouds.wordpress.com/2018/07/20/844/) 
via `values.yaml`. Helm-3's `--post-renderer` isn't batteries-included though; the sub-chart user must write a (usually simple) 
post-rending script and maintain kustomize resources independently. 

At the same time, various yaml-based tools (including Helm and kustomize) [deliberately eschew](https://kubernetes-sigs.github.io/kustomize/faq/eschewedfeatures/#build-time-side-effects-from-cli-args-or-env-variables) all but basic templating functions,
preferring to keep configuration 'simple' (*cough*) and deterministic. Tools like [ytt](https://get-ytt.io/)
and [dhall](https://github.com/dhall-lang) bring sophisticated scripting abilities to yaml, but are complex domain-specific
languages. 

Kush includes an option to interpolate inline-bash from included kustomize resources and charts 
and source included scripts during deployment. This is less secure than ytt and dhall (because it runs arbitrary code hosted
in charts as part of the deployment process), but very flexible and accessible. Interpolation must be enabled with
`--kush-interpolate`. 

## Known Bugs / TODOs

Helm post-rendering is known not to work with resources that utilize helm hooks, see [https://github.com/helm/helm/issues/7891](https://github.com/helm/helm/issues/7891) for details.

Interpolation/scripting errors frequently result in silent output (gobbled up by helm I think). 

Errors don't stop further processing when they should.

Using `--generate-name` is not supported, and parsing of release name and chart currently assumes these are
the first options, as in `helm kush template my-release-name chart-repo/chart ...`. 

## Prerequisites and Installation

Helm 3.X and kubectl version 1.14 or above. 

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
helm kush template myrelease kush-examples/interpolation-example --kush-interpolate \
  --values <(wget https://raw.githubusercontent.com/oneilsh/helm-kush/master/example-charts/interpolation-example/custom-values.yaml -qO -)
```


## Usage: Chart Authoring

### Basic Kustomization

Let's start by creating a basic chart with `helm create`, and remove the `templates/tests/test-connection.yaml` since it uses a helm hook 
and these are currently [buggy](https://github.com/helm/helm/issues/7891) with `--post-renderer`.

```
helm create basic-chart
rm basic-chart/templates/tests/test-connection.yaml
```

Next create a `kush` directory to hold kustomization files. 

```
mkdir basic-chart/kush
```

We'll add a `kustomization.yaml` file (required name), which must have at least `helm-template-output.yaml` listed as a resource (the result
of running `helm template` on the base chart); we'll also modify the deployment so we'll specify a patch with `patch-deployment.yaml`:

**`basic-chart/kush/kustomization.yaml`**:
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

**`basic-chart/kush/patch-deployment.yaml`**:
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

And that's it; `basic-chart` can now be deployed with `helm kush` without the need for forking the upstream chart, and we get kustomize 
resources 'bundled' with the chart. This can be handy in cases where kustomize is used with a custom chart but the files need to match
the chart version. 

### Interpolation

Start with a similar setup as above:

```
helm create interpolate-chart
rm interpolate-chart/templates/tests/test-connection.yaml
mkdir interpolate-chart/kush
```

And the same `kustomization.yaml` file.

**`interpolate-chart/kush/kustomization.yaml`**:
```
resources:
    - helm-template-output.yaml
patchesStrategicMerge:
    - patch-deployment.yaml
```








