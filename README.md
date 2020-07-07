# helm-kush

Helm plugin for in-chart kustomizations and optional bash interpolation.

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

## Prerequisites and Installation

Helm 3.X and kubectl version 1.14 or above. 

Install with: 

```
helm plugin install https://github.com/oneilsh/helm-kush
```

## Usage: Chart Install

Kush-enabled charts will contain a `kush` directory with kustomize resources for post-rendering. Helm kush 
currently only supports post-rendering for `install`, `upgrade`, and `template`. (Charts withough `kush` directories
are treated as normally.)

Examples:

First, add this repo as a helm chart repo and see the example chart:

```
helm repo add kush-examples https://oneilsh.github.io/helm-kush/
helm search repo kush-examples
```

Some example runs:

```
helm kush template myrelease kush-examples/example-kush-chart
```





