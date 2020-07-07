# helm-kush

Helm plugin for in-chart kustomizations and optional bash interpolation.

## Overview

Kush (from kustomize-sh) is a simple `helm` plugin allowing [kustomize](https://kustomize.io/) directories to be 
stored within Helm [charts](https://helm.sh/docs/chart_template_guide/getting_started/) and used for post-rendering. 

Kustomize (or `kubectl kustomize`) when used for post-rendering of Helm charts solves a common problem: third-party 
charts included as dependencies frequently don't expose as much [flexibility as we'd like](https://testingclouds.wordpress.com/2018/07/20/844/) 
via `values.yaml`. Helm-3's `--post-renderer` isn't batteries-included though; the sub-chart user must write a (usually simple) 
post-rending script and maintain kustomize resources independently. 

At the same time, various yaml-based tools (including Helm and kustomize) eschew all but basic templating functions,
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



