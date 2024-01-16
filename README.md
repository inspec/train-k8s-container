# train-k8s-container - Train Plugin for connecting to Kubernetes Containers for use with Chef InSpec

* **Project State: Active**
* **Issues Response SLA: 3 business days**
* **Pull Request Response SLA: 3 business days**

For more information on project states and SLAs, see [this documentation](https://github.com/chef/chef-oss-practices/blob/master/repo-management/repo-states.md).

This plugin allows applications that rely on Train to communicate with the Kubernetes API.  For example, InSpec uses this to perform compliance checks against Kubernetes Containers.

Train itself has no CLI, nor a sophisticated test harness.  InSpec does have such facilities, so installing Train plugins will require an InSpec installation.  You do not need to use or understand InSpec.

Train plugins may be developed without an InSpec installation.

## To Install this as a User

Train plugins are distributed as gems.  You may choose to manage the gem yourself, but if you are an InSpec user, InSPec can handle it for you.

You will need InSpec v2.3 or later.

Simply run:

```bash
$ inspec plugin install train-k8s-container
```

## Configuration

Below are the two mandatory pre-requisites for this plugin to work.
- `train-k8s-container` creates connection to k8s containers using the [kubeconfig](https://kubernetes.io/docs/concepts/configuration/organize-cluster-access-kubeconfig/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/#kubectl)
Both the kubeconfig and kubectl has to be present on the host machine from where this plugin is executed 

By default, it looks for the kubeconfig file in `~/.kube/config`. It can be overridden by the `ENV["KUBECONFIG"]`.

## Parameters

`pod` and `container_name` are two mandatory parameters. `namespace` is optional only if the namespace is a `default` k8s namespace.
You can then run the Inspec using the `--target` / `-t` option, using the format `-t k8s-container://<namespace>/<pod>/<container_name>`:
for example, 
In order to connect to a container `nginx` of pod `shell-demo` running on `prod` namespace 
the URI would be `k8s-container://prod/shell-demo/nginx`
if in case the targeted container is on a `default` namespace, it can be skipped like this `k8s-container:///shell-demo/nginx`

```bash
$ inspec detect -t k8s-container://default/shell-demo/nginx

 ────────────────────────────── Platform Details ──────────────────────────────

Name:      k8s-container
Families:  os
Release:   1.1.1
Arch:      unknown
```

```bash
$ inspec shell -t k8s-container:///shell-demo/nginx

Welcome to the interactive InSpec Shell
To find out how to use it, type: help

You are currently running on:

    Name:      k8s-container
    Families:  os
    Release:   1.1.1
    Arch:      unknown

inspec>
```

## Reporting Issues

Bugs, typos, limitations, and frustrations are welcome to be reported through the [GitHub issues page for the train-k8s-container project](https://github.com/inspec/train-k8s-container/issues).

You may also ask questions in the #inspec channel of the Chef Community Slack team.  However, for an issue to get traction, please report it as a github issue.

## Development on this Plugin

### Development Process

If you wish to contribute to this plugin, please use the usual fork-branch-push-PR cycle.  All functional changes need new tests, and bugfixes are expected to include a new test that demonstrates the bug.

### Reference Information

[Plugin Development](https://github.com/inspec/train/blob/master/docs/dev/plugins.md) is documented on the `train` project on GitHub.