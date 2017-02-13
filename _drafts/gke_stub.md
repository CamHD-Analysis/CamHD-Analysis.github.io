The `gcloud` utility can be used to automatically set up a `kubeconfig` for the current cluster/project.  This is nice if you're working on one project at a time but I still think it leaves you open to problems if you're switching between projects.

The command

    aaron@ursine:~/workspace/camhd_analysis$ gcloud container clusters get-credentials cluster-1
    Fetching cluster endpoint and auth data.
    kubeconfig entry generated for cluster-1.

Will configure `kubectl` for the named cluster in the current project.

If everything is going right, then `kubectl cluster-info` will provide some, uh, cluster info.

    aaron@ursine:~/workspace/camhd_analysis$ kubectl cluster-info
    Kubernetes master is running at https://104.198.103.249
    GLBCDefaultBackend is running at https://104.198.103.249/api/v1/proxy/namespaces/kube-system/services/default-http-backend
    Heapster is running at https://104.198.103.249/api/v1/proxy/namespaces/kube-system/services/heapster
    KubeDNS is running at https://104.198.103.249/api/v1/proxy/namespaces/kube-system/services/kube-dns
    kubernetes-dashboard is running at https://104.198.103.249/api/v1/proxy/namespaces/kube-system/services/kubernetes-dashboard

This lists a bunch of administrative processes which GKE starts by default.

For what it's worth, there's also a useful web-based dashboard included with Kubernetes.  The simplest way to access it is through the `kubectl proxy` command which will start a local proxy server which connects to the remote UI process:

    aaron@ursine:~/workspace/camhd_analysis$ kubectl proxy
    Starting to serve on 127.0.0.1:8001

# Install Deis and Helm

Workflow uses
