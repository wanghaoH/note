![alt text][RX-M LLC]


# Kubernetes


## Lab 11 - etcd operations

Etcd is a highly consistent, distributed key-value store designed to reliably and quickly preserve and provide access to
critical data. It enables distributed coordination through distributed locking, leader elections, and write barriers. An
etcd cluster is intended for high availability and permanent data storage and retrieval.

In this lab we will setup and explore operations on a multi-node etcd cluster. Rather than starting individual computers
for each of the etcd nodes, we will run the nodes in docker containers, simulating a three node cluster.

During the lab you will:
- Startup three Ubuntu host containers
- Acquire the latest etcd binaries
- Install etcd in each of the containers
- Start a 3 node cluster
- Test the cluster with etcdctl
- Explore the features of etcdctl
- Add and remove nodes from the cluster
- Backup and restore nodes


### 1. Starting the etcd cluster containers

To simulate a multi node etcd cluster we will run three docker Ubuntu containers, treating each one like a separate
host. We will name the containers:
- nodea
- nodeb
- nodec

Run the three target containers:

```
user@ubuntu:~$ docker container run -itd --name nodea -h nodea ubuntu:16.04

Unable to find image 'ubuntu:16.04' locally
16.04: Pulling from library/ubuntu
0a01a72a686c: Pull complete
cc899a5544da: Pull complete
19197c550755: Pull complete
716d454e56b6: Pull complete
Digest: sha256:3f3ee50cb89bc12028bab7d1e187ae57f12b957135b91648702e835c37c6c971
Status: Downloaded newer image for ubuntu:16.04
40844c644e46c605360f8b628be50094c9750a7f34383fb46ebf795bdae3b24f

user@ubuntu:~$ docker container run -itd --name nodeb -h nodeb ubuntu:16.04

915c117a85bd2fb99354dcf6f0602a6ea8379b358f7510ce79641d4b2006b68a

user@ubuntu:~$ docker container run -itd --name nodec -h nodec ubuntu:16.04

d393c9a416a6395de38b78e1ada44b1664cb46a644c0e769a77d273f99493455

user@ubuntu:~$
```

Verify all three containers are up and running:

```
user@ubuntu:~$ docker container ls -f ancestor=ubuntu:16.04

CONTAINER ID        IMAGE               COMMAND             CREATED             STATUS              PORTS               NAMES
d393c9a416a6        ubuntu:16.04        "/bin/bash"         24 seconds ago      Up 23 seconds                           nodec
915c117a85bd        ubuntu:16.04        "/bin/bash"         28 seconds ago      Up 27 seconds                           nodeb
40844c644e46        ubuntu:16.04        "/bin/bash"         37 seconds ago      Up 36 seconds                           nodea

user@ubuntu:~$
```

By running the containers with the -i and -t switches we add support for console input from our host shell and by using
the -d switch the container is launched "detached" in the background. To connect to the container shells later we can
use the  `docker container attach` command and to detach from the container shells we can use the `^P ^Q` command
sequence.

Next list the IP addresses of each of the containers:

```
user@ubuntu:~$ docker container inspect nodea -f '{{.NetworkSettings.IPAddress}}'

172.17.0.2

user@ubuntu:~$ docker container inspect nodeb -f '{{.NetworkSettings.IPAddress}}'

172.17.0.3

user@ubuntu:~$ docker container inspect nodec -f '{{.NetworkSettings.IPAddress}}'

172.17.0.4

user@ubuntu:~$
```

The IP for nodea is .2, nodeb is .3 and nodec is .4 in the example above. We will need these IP addresses to tell our
etcd nodes how to find each other.  



### 2. Download the latest etcd distribution

Next let's download etcd. A tarball for Linux can be found in the coreos/etcd repo under releases.

Use wget to download the tarball that corresponds to our K8s version:

```
user@ubuntu:~$ wget https://github.com/etcd-io/etcd/releases/download/v3.4.3/etcd-v3.4.3-linux-amd64.tar.gz

--2020-01-30 00:05:27--  https://github.com/etcd-io/etcd/releases/download/v3.4.3/etcd-v3.4.3-linux-amd64.tar.gz
Resolving github.com (github.com)... 192.30.255.113
Connecting to github.com (github.com)|192.30.255.113|:443... connected.
HTTP request sent, awaiting response... 302 Found
Location: https://github-production-release-asset-2e65be.s3.amazonaws.com/11225014/e3083e80-f583-11e9-91d0-084dffe50098?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=AKIAIWNJYAX4CSVEH53A%2F20200130%2Fus-east-1%2Fs3%2Faws4_request&X-Amz-Date=20200130T000527Z&X-Amz-Expires=300&X-Amz-Signature=e7178e96b1af41bb52552fe6cce7b24c08318cad364a2272c97c4edf0333d890&X-Amz-SignedHeaders=host&actor_id=0&response-content-disposition=attachment%3B%20filename%3Detcd-v3.4.3-linux-amd64.tar.gz&response-content-type=application%2Foctet-stream [following]
--2020-01-30 00:05:27--  https://github-production-release-asset-2e65be.s3.amazonaws.com/11225014/e3083e80-f583-11e9-91d0-084dffe50098?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=AKIAIWNJYAX4CSVEH53A%2F20200130%2Fus-east-1%2Fs3%2Faws4_request&X-Amz-Date=20200130T000527Z&X-Amz-Expires=300&X-Amz-Signature=e7178e96b1af41bb52552fe6cce7b24c08318cad364a2272c97c4edf0333d890&X-Amz-SignedHeaders=host&actor_id=0&response-content-disposition=attachment%3B%20filename%3Detcd-v3.4.3-linux-amd64.tar.gz&response-content-type=application%2Foctet-stream
Resolving github-production-release-asset-2e65be.s3.amazonaws.com (github-production-release-asset-2e65be.s3.amazonaws.com)... 52.217.9.52
Connecting to github-production-release-asset-2e65be.s3.amazonaws.com (github-production-release-asset-2e65be.s3.amazonaws.com)|52.217.9.52|:443... connected.
HTTP request sent, awaiting response... 200 OK
Length: 17280028 (16M) [application/octet-stream]
Saving to: ‘etcd-v3.4.3-linux-amd64.tar.gz’

etcd-v3.4.3-linux-amd64.t 100%[==================================>]  16.48M  9.43MB/s    in 1.7s    

2020-01-30 00:05:29 (9.43 MB/s) - ‘etcd-v3.4.3-linux-amd64.tar.gz’ saved [17280028/17280028]

user@ubuntu:~$
```

Now extract the achieved files:

```
user@ubuntu:~$ mkdir etcd

user@ubuntu:~$ tar xzf etcd-*-linux-amd64.tar.gz -C etcd/ --strip-components=1

user@ubuntu:~$ ls -l etcd

total 40360
drwxr-xr-x 14 ubuntu ubuntu     4096 Oct 23 17:41 Documentation
-rwxr-xr-x  1 ubuntu ubuntu 23712096 Oct 23 17:41 etcd
-rwxr-xr-x  1 ubuntu ubuntu 17542688 Oct 23 17:41 etcdctl
-rw-r--r--  1 ubuntu ubuntu    43094 Oct 23 17:41 README-etcdctl.md
-rw-r--r--  1 ubuntu ubuntu     8431 Oct 23 17:41 README.md
-rw-r--r--  1 ubuntu ubuntu     7855 Oct 23 17:41 READMEv2-etcdctl.md

user@ubuntu:~$
```

The archive unpacks into a directory with the versioned name etcd. Inside the directory you will see a Documentation
directory containing documentation in markdown form, the binaries for etcd and etcdctl, along with several readme files.

Check the version of the etcd binary:  

```
user@ubuntu:~$ etcd/etcd --version

etcd Version: 3.4.3
Git SHA: 3cf2f69b5
Go Version: go1.12.12
Go OS/Arch: linux/amd64

user@ubuntu:~$
```

Perfect we have acquired the latest etcd!


### 3. Install etcd in the containers

Installing etcd is as easy as copying it onto the system path, in our case we'll copy it into each of the containers:

```
user@ubuntu:~$ docker container cp etcd/etcd nodea:/usr/bin/etcd

user@ubuntu:~$ docker container exec nodea ls -l /usr/bin/etcd

-rwxr-xr-x 1 1000 1000 22102784 Oct 11 17:25 /usr/bin/etcd

user@ubuntu:~$
```

Install etcd on the other two nodes:

```
user@ubuntu:~$ docker container cp etcd/etcd nodeb:/usr/bin/etcd

user@ubuntu:~$ docker container cp etcd/etcd nodec:/usr/bin/etcd

user@ubuntu:~$
```

Great, etcd is now installed and ready to run on all three of our "computers".


### 4. Start the first node in the cluster

Obviously we can not start all three nodes at once so we will have to bootstrap our cluster. When launching the nodes in
a new cluster we will need to use the following switches:

- `--name nodea` - this defines the human readable node name
- `--initial-advertise-peer-urls http://172.17.0.2:2380` - this defines the address to share with peers
- `--listen-peer-urls http://172.17.0.2:2380` - this defines the address to listen on for peer traffic
- `--listen-client-urls http://172.17.0.2:2379,http://127.0.0.1:2379` - this defines the address to listen on for clients
- `--advertise-client-urls http://172.17.0.2:2379` - this defines the address to advertise to peers for client traffic
- `--initial-cluster-token cluster-1` - this defines the token for the cluster
- `--initial-cluster nodea=http://172.17.0.2:2380,nodeb=http://172.17.0.3:2380,nodec=http://172.17.0.4:2380` - this
        defines the nodes in the cluster and their peer addresses and ports
- `--initial-cluster-state new` - this lets the cluster acquire quorum progressively as nodes are initially added

**In a new terminal**, attach to nodea and start the first node of the cluster:

```
user@ubuntu:~$ docker container attach nodea

root@nodea:/# etcd --name nodea \
--initial-advertise-peer-urls http://172.17.0.2:2380 \
--listen-peer-urls http://172.17.0.2:2380 \
--listen-client-urls http://172.17.0.2:2379,http://127.0.0.1:2379 \
--advertise-client-urls http://172.17.0.2:2379 \
--initial-cluster-token cluster-1 \
--initial-cluster nodea=http://172.17.0.2:2380,nodeb=http://172.17.0.3:2380,nodec=http://172.17.0.4:2380 \
--initial-cluster-state new

2020-01-21 16:03:23.067186 I | etcdmain: etcd Version: 3.3.17
2020-01-21 16:03:23.067218 I | etcdmain: Git SHA: 6d8052314
2020-01-21 16:03:23.067222 I | etcdmain: Go Version: go1.12.9
2020-01-21 16:03:23.067224 I | etcdmain: Go OS/Arch: linux/amd64
2020-01-21 16:03:23.067226 I | etcdmain: setting maximum number of CPUs to 2, total number of available CPUs is 2
2020-01-21 16:03:23.067230 W | etcdmain: no data-dir provided, using default data-dir ./nodea.etcd
2020-01-21 16:03:23.067309 I | embed: listening for peers on http://172.17.0.2:2380
2020-01-21 16:03:23.067348 I | embed: listening for client requests on 127.0.0.1:2379
2020-01-21 16:03:23.067362 I | embed: listening for client requests on 172.17.0.2:2379
2020-01-21 16:03:23.068482 I | etcdserver: name = nodea
2020-01-21 16:03:23.068492 I | etcdserver: data dir = nodea.etcd
2020-01-21 16:03:23.068497 I | etcdserver: member dir = nodea.etcd/member
2020-01-21 16:03:23.068502 I | etcdserver: heartbeat = 100ms
2020-01-21 16:03:23.068505 I | etcdserver: election = 1000ms
2020-01-21 16:03:23.068509 I | etcdserver: snapshot count = 100000
2020-01-21 16:03:23.068515 I | etcdserver: advertise client URLs = http://172.17.0.2:2379
2020-01-21 16:03:23.068520 I | etcdserver: initial advertise peer URLs = http://172.17.0.2:2380
2020-01-21 16:03:23.068531 I | etcdserver: initial cluster = nodea=http://172.17.0.2:2380,nodeb=http://172.17.0.3:2380,nodec=http://172.17.0.4:2380
2020-01-21 16:03:23.069769 I | etcdserver: starting member 5c1954e5cd7a3e68 in cluster 89c79295f798999a
2020-01-21 16:03:23.069830 I | raft: 5c1954e5cd7a3e68 became follower at term 0
2020-01-21 16:03:23.069852 I | raft: newRaft 5c1954e5cd7a3e68 [peers: [], term: 0, commit: 0, applied: 0, lastindex: 0, lastterm: 0]
2020-01-21 16:03:23.069870 I | raft: 5c1954e5cd7a3e68 became follower at term 1
2020-01-21 16:03:23.071563 W | auth: simple token is not cryptographically signed
2020-01-21 16:03:23.072479 I | rafthttp: starting peer 507ecf5e9ca6b606...
2020-01-21 16:03:23.072511 I | rafthttp: started HTTP pipelining with peer 507ecf5e9ca6b606
2020-01-21 16:03:23.072975 I | rafthttp: started streaming with peer 507ecf5e9ca6b606 (writer)
2020-01-21 16:03:23.073244 I | rafthttp: started streaming with peer 507ecf5e9ca6b606 (writer)
2020-01-21 16:03:23.074075 I | rafthttp: started peer 507ecf5e9ca6b606
2020-01-21 16:03:23.074108 I | rafthttp: added peer 507ecf5e9ca6b606
2020-01-21 16:03:23.074283 I | rafthttp: starting peer 69b68fd2de47b0f9...
2020-01-21 16:03:23.074306 I | rafthttp: started HTTP pipelining with peer 69b68fd2de47b0f9
2020-01-21 16:03:23.074381 I | rafthttp: started streaming with peer 507ecf5e9ca6b606 (stream Message reader)
2020-01-21 16:03:23.074949 I | rafthttp: started streaming with peer 507ecf5e9ca6b606 (stream MsgApp v2 reader)
2020-01-21 16:03:23.075405 I | rafthttp: started streaming with peer 69b68fd2de47b0f9 (writer)
2020-01-21 16:03:23.075744 I | rafthttp: started streaming with peer 69b68fd2de47b0f9 (writer)
2020-01-21 16:03:23.075996 I | rafthttp: started peer 69b68fd2de47b0f9
2020-01-21 16:03:23.076118 I | rafthttp: added peer 69b68fd2de47b0f9
2020-01-21 16:03:23.076152 I | etcdserver: starting server... [version: 3.3.17, cluster version: to_be_decided]
2020-01-21 16:03:23.078820 I | rafthttp: started streaming with peer 69b68fd2de47b0f9 (stream MsgApp v2 reader)
2020-01-21 16:03:23.079051 I | rafthttp: started streaming with peer 69b68fd2de47b0f9 (stream Message reader)
2020-01-21 16:03:23.079764 I | etcdserver/membership: added member 507ecf5e9ca6b606 [http://172.17.0.3:2380] to cluster 89c79295f798999a
2020-01-21 16:03:23.079947 I | etcdserver/membership: added member 5c1954e5cd7a3e68 [http://172.17.0.2:2380] to cluster 89c79295f798999a
2020-01-21 16:03:23.079998 I | etcdserver/membership: added member 69b68fd2de47b0f9 [http://172.17.0.4:2380] to cluster 89c79295f798999a
2020-01-21 16:03:24.571332 I | raft: 5c1954e5cd7a3e68 is starting a new election at term 1


...
```

Reading the log output answer these questions:

- What data directory did etcd create?
- What two IP addresses are listening for client connections?
- Why would these two IPs be used for clients?
- How many WAL entries will the server record before taking a snapshot?
- What is nodea's member ID?
- What is your cluster ID?
- What are the IDs of the other two peer nodes?
- Are any of the leader elections that nodea is starting completing?

We will **leave the terminal for nodea open** so that we can monitor its activity. In a new terminal explore the data
directory for nodea:

```
user@ubuntu:~$ docker container exec nodea ls -l /nodea.etcd

total 4
drwx------ 4 root root 4096 Jan 30 00:08 member

user@ubuntu:~$ docker container exec nodea ls -l /nodea.etcd/member

total 8
drwx------ 2 root root 4096 Jan 30 00:08 snap
drwx------ 2 root root 4096 Jan 30 00:08 wal

user@ubuntu:~$
```

So at this stage, nodea is started but the cluster is not operational because a leader can not be elected with out a
majority of nodes in agreement. Let's start a second node!


### 5. Start the second node in the cluster

**Start a new terminal** and launch nodeb with the same switches as nodea, changing the name to nodeb and updating the IP
addresses for nodeb:

```
user@ubuntu:~$ docker container attach nodeb

root@nodeb:/# etcd --name nodeb \
--initial-advertise-peer-urls http://172.17.0.3:2380 \
--listen-peer-urls http://172.17.0.3:2380 \
--listen-client-urls http://172.17.0.3:2379,http://127.0.0.1:2379 \
--advertise-client-urls http://172.17.0.3:2379 \
--initial-cluster-token cluster-1 \
--initial-cluster nodea=http://172.17.0.2:2380,nodeb=http://172.17.0.3:2380,nodec=http://172.17.0.4:2380 \
--initial-cluster-state new

2020-01-21 16:06:57.531514 I | etcdmain: etcd Version: 3.3.17
2020-01-21 16:06:57.531562 I | etcdmain: Git SHA: 6d8052314
2020-01-21 16:06:57.531566 I | etcdmain: Go Version: go1.12.9
2020-01-21 16:06:57.531568 I | etcdmain: Go OS/Arch: linux/amd64
2020-01-21 16:06:57.531570 I | etcdmain: setting maximum number of CPUs to 2, total number of available CPUs is 2
2020-01-21 16:06:57.531575 W | etcdmain: no data-dir provided, using default data-dir ./nodeb.etcd
2020-01-21 16:06:57.531746 I | embed: listening for peers on http://172.17.0.3:2380
2020-01-21 16:06:57.531777 I | embed: listening for client requests on 127.0.0.1:2379
2020-01-21 16:06:57.531817 I | embed: listening for client requests on 172.17.0.3:2379
2020-01-21 16:06:57.533490 I | etcdserver: name = nodeb
2020-01-21 16:06:57.533617 I | etcdserver: data dir = nodeb.etcd
2020-01-21 16:06:57.533704 I | etcdserver: member dir = nodeb.etcd/member
2020-01-21 16:06:57.533787 I | etcdserver: heartbeat = 100ms
2020-01-21 16:06:57.533825 I | etcdserver: election = 1000ms
2020-01-21 16:06:57.533892 I | etcdserver: snapshot count = 100000
2020-01-21 16:06:57.533931 I | etcdserver: advertise client URLs = http://172.17.0.3:2379
2020-01-21 16:06:57.534008 I | etcdserver: initial advertise peer URLs = http://172.17.0.3:2380
2020-01-21 16:06:57.534049 I | etcdserver: initial cluster = nodea=http://172.17.0.2:2380,nodeb=http://172.17.0.3:2380,nodec=http://172.17.0.4:2380
2020-01-21 16:06:57.535556 I | etcdserver: starting member 507ecf5e9ca6b606 in cluster 89c79295f798999a
2020-01-21 16:06:57.535696 I | raft: 507ecf5e9ca6b606 became follower at term 0
2020-01-21 16:06:57.535804 I | raft: newRaft 507ecf5e9ca6b606 [peers: [], term: 0, commit: 0, applied: 0, lastindex: 0, lastterm: 0]
2020-01-21 16:06:57.535843 I | raft: 507ecf5e9ca6b606 became follower at term 1

...
```

Reading the nodeb log answer the following questions:

- Does the nodeb ID reported by nodeb match the one of the IDs reported by nodea?
- Locate the line with this text: "peer xxxxxxxxxxx became active", where xxxxxxxxxxx is some member ID. Which node is
    this line referring to? What is it telling us?
- Locate the line with this text "received a MsgVote message with higher term from". Which member is referred to in
    this line? Is nodeb the leader?
- Is nodeb ready to serve clients?
- Examine the new log output on nodea, what was the initial cluster version set to?

Great, we now have an active cluster with 2 nodes! We are in the danger zone however, because if we lose a node we lose quorum and our cluster goes down. Let's add the third node.


### 6. Start the final node in the cluster

**In another new terminal** launch nodec with the same switches as nodea and nodeb, changing the name to nodec and updating
the IP addresses for nodec:

```
user@ubuntu:~$ docker container attach nodec

root@66488ce9febb:/# etcd --name nodec \
--initial-advertise-peer-urls http://172.17.0.4:2380 \
--listen-peer-urls http://172.17.0.4:2380 \
--listen-client-urls http://172.17.0.4:2379,http://127.0.0.1:2379 \
--advertise-client-urls http://172.17.0.4:2379 \
--initial-cluster-token cluster-1 \
--initial-cluster nodea=http://172.17.0.2:2380,nodeb=http://172.17.0.3:2380,nodec=http://172.17.0.4:2380 \
--initial-cluster-state new

2020-01-21 16:09:13.749700 I | etcdmain: etcd Version: 3.3.17
2020-01-21 16:09:13.749813 I | etcdmain: Git SHA: 6d8052314
2020-01-21 16:09:13.749819 I | etcdmain: Go Version: go1.12.9
2020-01-21 16:09:13.749823 I | etcdmain: Go OS/Arch: linux/amd64
2020-01-21 16:09:13.749828 I | etcdmain: setting maximum number of CPUs to 2, total number of available CPUs is 2
2020-01-21 16:09:13.749989 W | etcdmain: no data-dir provided, using default data-dir ./nodec.etcd
2020-01-21 16:09:13.750252 I | embed: listening for peers on http://172.17.0.4:2380
2020-01-21 16:09:13.750332 I | embed: listening for client requests on 127.0.0.1:2379
2020-01-21 16:09:13.750438 I | embed: listening for client requests on 172.17.0.4:2379
2020-01-21 16:09:13.752854 I | etcdserver: name = nodec
2020-01-21 16:09:13.752874 I | etcdserver: data dir = nodec.etcd
2020-01-21 16:09:13.752880 I | etcdserver: member dir = nodec.etcd/member
2020-01-21 16:09:13.752885 I | etcdserver: heartbeat = 100ms
2020-01-21 16:09:13.752889 I | etcdserver: election = 1000ms
2020-01-21 16:09:13.752960 I | etcdserver: snapshot count = 100000
2020-01-21 16:09:13.752982 I | etcdserver: advertise client URLs = http://172.17.0.4:2379
2020-01-21 16:09:13.752988 I | etcdserver: initial advertise peer URLs = http://172.17.0.4:2380
2020-01-21 16:09:13.753098 I | etcdserver: initial cluster = nodea=http://172.17.0.2:2380,nodeb=http://172.17.0.3:2380,nodec=http://172.17.0.4:2380
2020-01-21 16:09:13.754968 I | etcdserver: starting member 69b68fd2de47b0f9 in cluster 89c79295f798999a
2020-01-21 16:09:13.755059 I | raft: 69b68fd2de47b0f9 became follower at term 0
2020-01-21 16:09:13.755087 I | raft: newRaft 69b68fd2de47b0f9 [peers: [], term: 0, commit: 0, applied: 0, lastindex: 0, lastterm: 0]
2020-01-21 16:09:13.755094 I | raft: 69b68fd2de47b0f9 became follower at term 1
2020-01-21 16:09:13.797975 W | auth: simple token is not cryptographically signed
2020-01-21 16:09:13.799440 I | rafthttp: starting peer 507ecf5e9ca6b606...
2020-01-21 16:09:13.799495 I | rafthttp: started HTTP pipelining with peer 507ecf5e9ca6b606
2020-01-21 16:09:13.801064 I | rafthttp: started streaming with peer 507ecf5e9ca6b606 (writer)
2020-01-21 16:09:13.801216 I | rafthttp: started streaming with peer 507ecf5e9ca6b606 (writer)
2020-01-21 16:09:13.801584 I | rafthttp: started peer 507ecf5e9ca6b606
2020-01-21 16:09:13.801801 I | rafthttp: added peer 507ecf5e9ca6b606
2020-01-21 16:09:13.801826 I | rafthttp: starting peer 5c1954e5cd7a3e68...
2020-01-21 16:09:13.801899 I | rafthttp: started HTTP pipelining with peer 5c1954e5cd7a3e68
2020-01-21 16:09:13.801930 I | rafthttp: started streaming with peer 507ecf5e9ca6b606 (stream MsgApp v2 reader)
2020-01-21 16:09:13.802779 I | rafthttp: started streaming with peer 507ecf5e9ca6b606 (stream Message reader)
2020-01-21 16:09:13.803220 I | rafthttp: started streaming with peer 5c1954e5cd7a3e68 (writer)
2020-01-21 16:09:13.803839 I | rafthttp: started streaming with peer 5c1954e5cd7a3e68 (writer)
2020-01-21 16:09:13.804203 I | rafthttp: started peer 5c1954e5cd7a3e68
2020-01-21 16:09:13.804223 I | rafthttp: added peer 5c1954e5cd7a3e68
2020-01-21 16:09:13.804233 I | etcdserver: starting server... [version: 3.3.17, cluster version: to_be_decided]
2020-01-21 16:09:13.804371 I | rafthttp: peer 507ecf5e9ca6b606 became active
2020-01-21 16:09:13.804404 I | rafthttp: established a TCP streaming connection with peer 507ecf5e9ca6b606 (stream Message reader)
2020-01-21 16:09:13.804443 I | rafthttp: established a TCP streaming connection with peer 507ecf5e9ca6b606 (stream MsgApp v2 reader)
2020-01-21 16:09:13.804507 I | rafthttp: started streaming with peer 5c1954e5cd7a3e68 (stream MsgApp v2 reader)
2020-01-21 16:09:13.804772 I | rafthttp: started streaming with peer 5c1954e5cd7a3e68 (stream Message reader)
2020-01-21 16:09:13.807337 I | rafthttp: peer 5c1954e5cd7a3e68 became active
2020-01-21 16:09:13.807349 I | rafthttp: established a TCP streaming connection with peer 5c1954e5cd7a3e68 (stream MsgApp v2 reader)
2020-01-21 16:09:13.808108 I | rafthttp: established a TCP streaming connection with peer 5c1954e5cd7a3e68 (stream Message reader)
2020-01-21 16:09:13.830822 I | etcdserver/membership: added member 507ecf5e9ca6b606 [http://172.17.0.3:2380] to cluster 89c79295f798999a
2020-01-21 16:09:13.831087 I | etcdserver/membership: added member 5c1954e5cd7a3e68 [http://172.17.0.2:2380] to cluster 89c79295f798999a
2020-01-21 16:09:13.831191 I | etcdserver/membership: added member 69b68fd2de47b0f9 [http://172.17.0.4:2380] to cluster 89c79295f798999a
2020-01-21 16:09:13.831471 I | rafthttp: established a TCP streaming connection with peer 5c1954e5cd7a3e68 (stream Message writer)
2020-01-21 16:09:13.831588 I | rafthttp: established a TCP streaming connection with peer 507ecf5e9ca6b606 (stream MsgApp v2 writer)
2020-01-21 16:09:13.831663 I | rafthttp: established a TCP streaming connection with peer 507ecf5e9ca6b606 (stream Message writer)
2020-01-21 16:09:13.831781 I | raft: 69b68fd2de47b0f9 [term: 1] received a MsgHeartbeat message with higher term from 5c1954e5cd7a3e68 [term: 149]
2020-01-21 16:09:13.831798 I | raft: 69b68fd2de47b0f9 became follower at term 149

...
```

Reading the log output from nodec answer the following questions:

- What is the ID of nodec?
- Did nodec vote to elect nodea leader?
- How many of the other nodes is nodec connected to?
- What was the cluster version updated to? Why do you think this happened?

Fantastic, we have a fully operational cluster running!


### 7. Connecting to the cluster

**Return to a host terminal** (or create a new one). We will use the etcdctl tool to exercise our new cluster. To make
operations easier let's copy the etcdctl binary to the system path:

```
user@ubuntu:~$ sudo cp etcd/etcdctl /usr/bin

user@ubuntu:~$
```

Our cluster is running etcd v3 so we will want to set the v3 environment variable so that etcdctl uses the right
protocol. Set the environment variable and test etcdctl:

```
user@ubuntu:~$ export ETCDCTL_API=3

user@ubuntu:~$ etcdctl version

etcdctl version: 3.4.3
API version: 3.4

user@ubuntu:~$
```

In order to access the cluster we will need to provide etcdctl with at least one of the cluster client endpoints.
However if we give etcdctl all of the client endpoints, even if a node is down we will still be able to interact with
the remaining nodes.  

Try listing the cluster members using the client endpoint list for the entire cluster:

```
user@ubuntu:~$ etcdctl --endpoints=[172.17.0.2:2379,172.17.0.3:2379,172.17.0.4:2379] member list

507ecf5e9ca6b606, started, nodeb, http://172.17.0.3:2380, http://172.17.0.3:2379, false
5c1954e5cd7a3e68, started, nodea, http://172.17.0.2:2380, http://172.17.0.2:2379, false
69b68fd2de47b0f9, started, nodec, http://172.17.0.4:2380, http://172.17.0.4:2379, false

user@ubuntu:~$
```

It works! Now display the help for the member list command:

```
user@ubuntu:~$ etcdctl --endpoints=[172.17.0.2:2379,172.17.0.3:2379,172.17.0.4:2379] member list --help
NAME:
	member list - Lists all members in the cluster

USAGE:
	etcdctl member list [flags]

DESCRIPTION:
	When --write-out is set to simple, this command prints out comma-separated member lists for each endpoint.
	The items in the lists are ID, Status, Name, Peer Addrs, Client Addrs, Is Learner.

OPTIONS:
  -h, --help[=false]	help for list

GLOBAL OPTIONS:
      --cacert=""				verify certificates of TLS-enabled secure servers using this CA bundle
      --cert=""					identify secure client using this TLS certificate file
      --command-timeout=5s			timeout for short running command (excluding dial timeout)
      --debug[=false]				enable client-side debug logging
      --dial-timeout=2s				dial timeout for client connections
  -d, --discovery-srv=""			domain name to query for SRV records describing cluster endpoints
      --discovery-srv-name=""			service name to query when using DNS discovery
      --endpoints=[127.0.0.1:2379]		gRPC endpoints
      --hex[=false]				print byte strings as hex encoded strings
      --insecure-discovery[=true]		accept insecure SRV records describing cluster endpoints
      --insecure-skip-tls-verify[=false]	skip server certificate verification
      --insecure-transport[=true]		disable transport security for client connections
      --keepalive-time=2s			keepalive time for client connections
      --keepalive-timeout=6s			keepalive timeout for client connections
      --key=""					identify secure client using this TLS key file
      --password=""				password for authentication (if this option is used, --user option shouldn't include password)
      --user=""					username[:password] for authentication (prompt if password is not supplied)
  -w, --write-out="simple"			set the output format (fields, json, protobuf, simple, table)

user@ubuntu:~$
```

The member list command supports JSON output. Try it:

```
user@ubuntu:~$ etcdctl --endpoints=[172.17.0.2:2379,172.17.0.3:2379,172.17.0.4:2379] member list -w="json"

{"header":{"cluster_id":9928065076363303322,"member_id":5800301375361824262,"raft_term":126},"members":[{"ID":5800301375361824262,"name":"nodeb","peerURLs":["http://172.17.0.3:2380"],"clientURLs":["http://172.17.0.3:2379"]},{"ID":6636428871878721128,"name":"nodea","peerURLs":["http://172.17.0.2:2380"],"clientURLs":["http://172.17.0.2:2379"]},{"ID":7617433955578917113,"name":"nodec","peerURLs":["http://172.17.0.4:2380"],"clientURLs":["http://172.17.0.4:2379"]}]}

user@ubuntu:~$
```

Nice, now we can extract machine readable data from etcd. However, it is not fun entering in the end point addresses
with each command. We can set an environment variable for the cluster end points so simplify things. Try it:

```
user@ubuntu:~$ export ETCDCTL_ENDPOINTS=172.17.0.2:2379,172.17.0.3:2379,172.17.0.4:2379

user@ubuntu:~$ etcdctl member list

507ecf5e9ca6b606, started, nodeb, http://172.17.0.3:2380, http://172.17.0.3:2379, false
5c1954e5cd7a3e68, started, nodea, http://172.17.0.2:2380, http://172.17.0.2:2379, false
69b68fd2de47b0f9, started, nodec, http://172.17.0.4:2380, http://172.17.0.4:2379, false

user@ubuntu:~$
```

Much better. Now run a health check on the cluster:

```
user@ubuntu:~$ etcdctl endpoint health

172.17.0.3:2379 is healthy: successfully committed proposal: took = 3.762074ms
172.17.0.2:2379 is healthy: successfully committed proposal: took = 4.17689ms
172.17.0.4:2379 is healthy: successfully committed proposal: took = 4.405628ms

user@ubuntu:~$
```

Everything looks good. Let's try saving a key/value pair:

```
user@ubuntu:~$ etcdctl put testport 7777

OK

user@ubuntu:~$ etcdctl get testport

testport
7777

user@ubuntu:~$
```

Our etcd cluster is working!

Examine the help and try some other get command variants:

```
user@ubuntu:~$ etcdctl get --help
NAME:
	get - Gets the key or a range of keys

USAGE:
	etcdctl get [options] <key> [range_end] [flags]

OPTIONS:
      --consistency="l"			Linearizable(l) or Serializable(s)
      --from-key[=false]		Get keys that are greater than or equal to the given key using byte compare
  -h, --help[=false]			help for get
      --keys-only[=false]		Get only the keys
      --limit=0				Maximum number of results
      --order=""			Order of results; ASCEND or DESCEND (ASCEND by default)
      --prefix[=false]			Get keys with matching prefix
      --print-value-only[=false]	Only write values when using the "simple" output format
      --rev=0				Specify the kv revision
      --sort-by=""			Sort target; CREATE, KEY, MODIFY, VALUE, or VERSION

GLOBAL OPTIONS:
      --cacert=""				verify certificates of TLS-enabled secure servers using this CA bundle
      --cert=""					identify secure client using this TLS certificate file
      --command-timeout=5s			timeout for short running command (excluding dial timeout)
      --debug[=false]				enable client-side debug logging
      --dial-timeout=2s				dial timeout for client connections
  -d, --discovery-srv=""			domain name to query for SRV records describing cluster endpoints
      --discovery-srv-name=""			service name to query when using DNS discovery
      --endpoints=[127.0.0.1:2379]		gRPC endpoints
      --hex[=false]				print byte strings as hex encoded strings
      --insecure-discovery[=true]		accept insecure SRV records describing cluster endpoints
      --insecure-skip-tls-verify[=false]	skip server certificate verification
      --insecure-transport[=true]		disable transport security for client connections
      --keepalive-time=2s			keepalive time for client connections
      --keepalive-timeout=6s			keepalive timeout for client connections
      --key=""					identify secure client using this TLS key file
      --password=""				password for authentication (if this option is used, --user option shouldn't include password)
      --user=""					username[:password] for authentication (prompt if password is not supplied)
  -w, --write-out="simple"			set the output format (fields, json, protobuf, simple, table)

user@ubuntu:~$ etcdctl get testport --print-value-only

7777

user@ubuntu:~$ etcdctl get test --print-value-only --prefix

7777

user@ubuntu:~$
```

Perfect we have a working cluster and a configured client!


### 8. Remove a node

Remove nodec from the cluster (but leave the container running):

```
user@ubuntu:~$ etcdctl member list

507ecf5e9ca6b606, started, nodeb, http://172.17.0.3:2380, http://172.17.0.3:2379, false
5c1954e5cd7a3e68, started, nodea, http://172.17.0.2:2380, http://172.17.0.2:2379, false
69b68fd2de47b0f9, started, nodec, http://172.17.0.4:2380, http://172.17.0.4:2379, false

user@ubuntu:~$ etcdctl member remove 69b68fd2de47b0f9

Member 69b68fd2de47b0f9 removed from cluster 89c79295f798999a

user@ubuntu:~$
```

Review the logs from nodec:

```
user@ubuntu:~$ docker container logs nodec --tail 20

2020-01-30 00:17:17.535090 W | rafthttp: lost the TCP streaming connection with peer 507ecf5e9ca6b606 (stream Message reader)
2020-01-30 00:17:17.537291 E | rafthttp: failed to dial 507ecf5e9ca6b606 on stream MsgApp v2 (the member has been permanently removed from the cluster)
2020-01-30 00:17:17.537310 I | rafthttp: peer 507ecf5e9ca6b606 became inactive (message send to peer failed)
2020-01-30 00:17:17.538155 I | rafthttp: closed the TCP streaming connection with peer 507ecf5e9ca6b606 (stream MsgApp v2 writer)
2020-01-30 00:17:17.538174 I | rafthttp: stopped streaming with peer 507ecf5e9ca6b606 (writer)
2020-01-30 00:17:17.539590 I | rafthttp: closed the TCP streaming connection with peer 507ecf5e9ca6b606 (stream Message writer)
2020-01-30 00:17:17.539608 I | rafthttp: stopped streaming with peer 507ecf5e9ca6b606 (writer)
2020-01-30 00:17:17.539635 I | rafthttp: stopped HTTP pipelining with peer 507ecf5e9ca6b606
2020-01-30 00:17:17.539652 I | rafthttp: stopped streaming with peer 507ecf5e9ca6b606 (stream MsgApp v2 reader)
2020-01-30 00:17:17.539667 I | rafthttp: stopped streaming with peer 507ecf5e9ca6b606 (stream Message reader)
2020-01-30 00:17:17.539678 I | rafthttp: stopped peer 507ecf5e9ca6b606
2020-01-30 00:17:17.539688 I | rafthttp: stopping peer 5c1954e5cd7a3e68...
2020-01-30 00:17:17.540632 I | rafthttp: closed the TCP streaming connection with peer 5c1954e5cd7a3e68 (stream MsgApp v2 writer)
2020-01-30 00:17:17.540646 I | rafthttp: stopped streaming with peer 5c1954e5cd7a3e68 (writer)
2020-01-30 00:17:17.541604 I | rafthttp: closed the TCP streaming connection with peer 5c1954e5cd7a3e68 (stream Message writer)
2020-01-30 00:17:17.541620 I | rafthttp: stopped streaming with peer 5c1954e5cd7a3e68 (writer)
2020-01-30 00:17:17.541644 I | rafthttp: stopped HTTP pipelining with peer 5c1954e5cd7a3e68
2020-01-30 00:17:17.541661 I | rafthttp: stopped streaming with peer 5c1954e5cd7a3e68 (stream MsgApp v2 reader)
2020-01-30 00:17:17.541677 I | rafthttp: stopped streaming with peer 5c1954e5cd7a3e68 (stream Message reader)
2020-01-30 00:17:17.541688 I | rafthttp: stopped peer 5c1954e5cd7a3e68

user@ubuntu:~$
```

Test the cluster, does it still work?

```
user@ubuntu:~$ etcdctl get testport

testport
7777

user@ubuntu:~$ etcdctl put newvalue 11111

OK

user@ubuntu:~$ etcdctl get newvalue

newvalue
11111

user@ubuntu:~$
```

Still working!


### 9. Create a new node

Create a new noded container to add to the cluster **in a new terminal**:

```
user@ubuntu:~$ docker container run -itd --name noded -h noded ubuntu:16.04

1dc2a9ac82e215f5ef25b0386ce6b81ab585eff84156d33223c771333b5d52e7

user@ubuntu:~$ docker container inspect noded -f '{{.NetworkSettings.IPAddress}}'

172.17.0.5

user@ubuntu:~$ docker container cp etcd/etcd noded:/usr/bin/etcd

user@ubuntu:~$
```

Back in the **host terminal**, add the new member to the etcd cluster by telling the other members about it:

```
user@ubuntu:~$ etcdctl member add noded --peer-urls=http://172.17.0.5:2380

Member 173bccef55f1a2d8 added to cluster 89c79295f798999a

{"level":"warn","ts":"2020-01-30T00:19:52.541Z","caller":"clientv3/retry_interceptor.go:61","msg":"retrying of unary invoker failed","target":"endpoint://client-1787cd25-3085-47dd-8e8a-b5765b4905ea/172.17.0.2:2379","attempt":0,"error":"rpc error: code = DeadlineExceeded desc = context deadline exceeded"}
Error: <nil>

user@ubuntu:~$
```

> N.B. If you see `Member 173bccef55f1a2d8 added to cluster 89c79295f798999a` then the new member was added. In some
> versions, a regression appears to cause etcd to report `retrying of unary invoker failed`. You can safely ignore the
> warning, though do note that there are currently issues open on the etcd regarding this issue. In other versions, you
> will see the following text block:
>```
>ETCD_NAME="noded"
>ETCD_INITIAL_CLUSTER="nodeb=http://172.17.0.3:2380,nodea=http://172.17.0.2:2380,noded=http://172.17.0.5:2380"
>ETCD_INITIAL_ADVERTISE_PEER_URLS="http://172.17.0.5:2380"
>ETCD_INITIAL_CLUSTER_STATE="existing"
>```

**In the noded terminal**, start the node:

```
user@ubuntu:~$ docker container attach noded

root@noded:/# etcd --name noded \
--initial-advertise-peer-urls http://172.17.0.5:2380 \
--listen-peer-urls http://172.17.0.5:2380 \
--listen-client-urls http://172.17.0.5:2379,http://127.0.0.1:2379 \
--advertise-client-urls http://172.17.0.5:2379 \
--initial-cluster-token cluster-1 \
--initial-cluster nodea=http://172.17.0.2:2380,nodeb=http://172.17.0.3:2380,noded=http://172.17.0.5:2380 \
--initial-cluster-state existing

2020-01-21 16:40:05.054145 I | etcdmain: etcd Version: 3.3.17
2020-01-21 16:40:05.054190 I | etcdmain: Git SHA: 6d8052314
2020-01-21 16:40:05.054196 I | etcdmain: Go Version: go1.12.9
2020-01-21 16:40:05.054200 I | etcdmain: Go OS/Arch: linux/amd64
2020-01-21 16:40:05.054225 I | etcdmain: setting maximum number of CPUs to 2, total number of available CPUs is 2
2020-01-21 16:40:05.054547 W | etcdmain: no data-dir provided, using default data-dir ./noded.etcd
2020-01-21 16:40:05.054747 I | embed: listening for peers on http://172.17.0.5:2380
2020-01-21 16:40:05.054790 I | embed: listening for client requests on 127.0.0.1:2379
2020-01-21 16:40:05.054931 I | embed: listening for client requests on 172.17.0.5:2379
2020-01-21 16:40:05.058421 I | etcdserver: name = noded
2020-01-21 16:40:05.058487 I | etcdserver: data dir = noded.etcd
2020-01-21 16:40:05.058491 I | etcdserver: member dir = noded.etcd/member
2020-01-21 16:40:05.058497 I | etcdserver: heartbeat = 100ms
2020-01-21 16:40:05.058521 I | etcdserver: election = 1000ms
2020-01-21 16:40:05.058524 I | etcdserver: snapshot count = 100000
2020-01-21 16:40:05.058531 I | etcdserver: advertise client URLs = http://172.17.0.5:2379
2020-01-21 16:40:05.062798 I | etcdserver: starting member f225f6fe98c6b0e6 in cluster 89c79295f798999a
2020-01-21 16:40:05.062848 I | raft: f225f6fe98c6b0e6 became follower at term 0
2020-01-21 16:40:05.062865 I | raft: newRaft f225f6fe98c6b0e6 [peers: [], term: 0, commit: 0, applied: 0, lastindex: 0, lastterm: 0]
2020-01-21 16:40:05.062878 I | raft: f225f6fe98c6b0e6 became follower at term 1
2020-01-21 16:40:05.067430 W | auth: simple token is not cryptographically signed
2020-01-21 16:40:05.069481 I | rafthttp: started HTTP pipelining with peer 507ecf5e9ca6b606
2020-01-21 16:40:05.069506 I | rafthttp: started HTTP pipelining with peer 5c1954e5cd7a3e68
2020-01-21 16:40:05.069517 I | rafthttp: starting peer 507ecf5e9ca6b606...
2020-01-21 16:40:05.069540 I | rafthttp: started HTTP pipelining with peer 507ecf5e9ca6b606
2020-01-21 16:40:05.070549 I | rafthttp: started streaming with peer 507ecf5e9ca6b606 (writer)
2020-01-21 16:40:05.070953 I | rafthttp: started streaming with peer 507ecf5e9ca6b606 (writer)
2020-01-21 16:40:05.072945 I | rafthttp: started peer 507ecf5e9ca6b606
2020-01-21 16:40:05.072986 I | rafthttp: added peer 507ecf5e9ca6b606
2020-01-21 16:40:05.072996 I | rafthttp: starting peer 5c1954e5cd7a3e68...
2020-01-21 16:40:05.073013 I | rafthttp: started HTTP pipelining with peer 5c1954e5cd7a3e68
2020-01-21 16:40:05.073472 I | rafthttp: started streaming with peer 507ecf5e9ca6b606 (stream MsgApp v2 reader)
2020-01-21 16:40:05.074188 I | rafthttp: started streaming with peer 507ecf5e9ca6b606 (stream Message reader)
2020-01-21 16:40:05.074445 I | rafthttp: started streaming with peer 5c1954e5cd7a3e68 (writer)
2020-01-21 16:40:05.074521 I | rafthttp: started streaming with peer 5c1954e5cd7a3e68 (writer)
2020-01-21 16:40:05.074747 I | rafthttp: started peer 5c1954e5cd7a3e68
2020-01-21 16:40:05.074763 I | rafthttp: added peer 5c1954e5cd7a3e68
2020-01-21 16:40:05.074777 I | etcdserver: starting server... [version: 3.3.17, cluster version: to_be_decided]
2020-01-21 16:40:05.075685 I | rafthttp: started streaming with peer 5c1954e5cd7a3e68 (stream MsgApp v2 reader)
2020-01-21 16:40:05.076334 I | rafthttp: started streaming with peer 5c1954e5cd7a3e68 (stream Message reader)
2020-01-21 16:40:05.079408 I | rafthttp: peer 5c1954e5cd7a3e68 became active
2020-01-21 16:40:05.079432 I | rafthttp: established a TCP streaming connection with peer 5c1954e5cd7a3e68 (stream MsgApp v2 reader)
2020-01-21 16:40:05.082534 I | raft: f225f6fe98c6b0e6 [term: 1] received a MsgHeartbeat message with higher term from 5c1954e5cd7a3e68 [term: 149]
2020-01-21 16:40:05.082653 I | raft: f225f6fe98c6b0e6 became follower at term 149
2020-01-21 16:40:05.082680 I | raft: raft.node: f225f6fe98c6b0e6 elected leader 5c1954e5cd7a3e68 at term 149
2020-01-21 16:40:05.083695 I | rafthttp: peer 507ecf5e9ca6b606 became active
2020-01-21 16:40:05.083710 I | rafthttp: established a TCP streaming connection with peer 507ecf5e9ca6b606 (stream Message reader)
2020-01-21 16:40:05.101445 I | rafthttp: established a TCP streaming connection with peer 5c1954e5cd7a3e68 (stream Message reader)
2020-01-21 16:40:05.101777 I | rafthttp: established a TCP streaming connection with peer 507ecf5e9ca6b606 (stream MsgApp v2 reader)
2020-01-21 16:40:05.107972 I | rafthttp: established a TCP streaming connection with peer 5c1954e5cd7a3e68 (stream MsgApp v2 writer)
2020-01-21 16:40:05.108885 I | rafthttp: established a TCP streaming connection with peer 5c1954e5cd7a3e68 (stream Message writer)
2020-01-21 16:40:05.142927 I | etcdserver: f225f6fe98c6b0e6 initialzed peer connection; fast-forwarding 8 ticks (election ticks 10) with 2 active peer(s)


...
```

In the host terminal verify your changes succeeded:

```

user@ubuntu:~$ etcdctl member list
173bccef55f1a2d8, started, noded, http://172.17.0.5:2380, http://172.17.0.5:2379, false
507ecf5e9ca6b606, started, nodeb, http://172.17.0.3:2380, http://172.17.0.3:2379, false
5c1954e5cd7a3e68, started, nodea, http://172.17.0.2:2380, http://172.17.0.2:2379, false

user@ubuntu:~$
```


### 10. Migrate a node

Now we will migrate noded to nodec and rejoin it as "noded" with the cluster.

Kill the noded etcd process (`^C`) but leave the container running

```
^C

2020-01-21 16:43:15.983458 N | pkg/osutil: received interrupt signal, shutting down...
2020-01-21 16:43:15.983643 I | etcdserver: skipped leadership transfer for stopping non-leader member
2020-01-21 16:43:15.983721 I | rafthttp: stopped HTTP pipelining with peer 507ecf5e9ca6b606
2020-01-21 16:43:15.983732 I | rafthttp: stopped HTTP pipelining with peer 5c1954e5cd7a3e68
2020-01-21 16:43:15.983737 I | rafthttp: stopped HTTP pipelining with peer f225f6fe98c6b0e6
2020-01-21 16:43:15.983751 I | rafthttp: stopping peer 507ecf5e9ca6b606...
2020-01-21 16:43:15.995610 I | rafthttp: closed the TCP streaming connection with peer 507ecf5e9ca6b606 (stream MsgApp v2 writer)
2020-01-21 16:43:15.995636 I | rafthttp: stopped streaming with peer 507ecf5e9ca6b606 (writer)
2020-01-21 16:43:16.013176 I | rafthttp: closed the TCP streaming connection with peer 507ecf5e9ca6b606 (stream Message writer)
2020-01-21 16:43:16.013206 I | rafthttp: stopped streaming with peer 507ecf5e9ca6b606 (writer)
2020-01-21 16:43:16.013231 I | rafthttp: stopped HTTP pipelining with peer 507ecf5e9ca6b606
2020-01-21 16:43:16.013329 W | rafthttp: lost the TCP streaming connection with peer 507ecf5e9ca6b606 (stream MsgApp v2 reader)
2020-01-21 16:43:16.013351 I | rafthttp: stopped streaming with peer 507ecf5e9ca6b606 (stream MsgApp v2 reader)
2020-01-21 16:43:16.013409 W | rafthttp: lost the TCP streaming connection with peer 507ecf5e9ca6b606 (stream Message reader)
2020-01-21 16:43:16.013425 E | rafthttp: failed to read 507ecf5e9ca6b606 on stream Message (context canceled)
2020-01-21 16:43:16.013438 I | rafthttp: peer 507ecf5e9ca6b606 became inactive (message send to peer failed)
2020-01-21 16:43:16.013441 I | rafthttp: stopped streaming with peer 507ecf5e9ca6b606 (stream Message reader)
2020-01-21 16:43:16.013456 I | rafthttp: stopped peer 507ecf5e9ca6b606
2020-01-21 16:43:16.013480 I | rafthttp: stopping peer 5c1954e5cd7a3e68...
2020-01-21 16:43:16.013685 I | rafthttp: closed the TCP streaming connection with peer 5c1954e5cd7a3e68 (stream MsgApp v2 writer)
2020-01-21 16:43:16.013700 I | rafthttp: stopped streaming with peer 5c1954e5cd7a3e68 (writer)
2020-01-21 16:43:16.013991 I | rafthttp: closed the TCP streaming connection with peer 5c1954e5cd7a3e68 (stream Message writer)
2020-01-21 16:43:16.013997 I | rafthttp: stopped streaming with peer 5c1954e5cd7a3e68 (writer)
2020-01-21 16:43:16.014063 I | rafthttp: stopped HTTP pipelining with peer 5c1954e5cd7a3e68
2020-01-21 16:43:16.014119 W | rafthttp: lost the TCP streaming connection with peer 5c1954e5cd7a3e68 (stream MsgApp v2 reader)
2020-01-21 16:43:16.014126 E | rafthttp: failed to read 5c1954e5cd7a3e68 on stream MsgApp v2 (context canceled)
2020-01-21 16:43:16.014128 I | rafthttp: peer 5c1954e5cd7a3e68 became inactive (message send to peer failed)
2020-01-21 16:43:16.014131 I | rafthttp: stopped streaming with peer 5c1954e5cd7a3e68 (stream MsgApp v2 reader)
2020-01-21 16:43:16.014346 W | rafthttp: lost the TCP streaming connection with peer 5c1954e5cd7a3e68 (stream Message reader)
2020-01-21 16:43:16.014353 I | rafthttp: stopped streaming with peer 5c1954e5cd7a3e68 (stream Message reader)
2020-01-21 16:43:16.014355 I | rafthttp: stopped peer 5c1954e5cd7a3e68
2020-01-21 16:43:16.014553 E | rafthttp: failed to find member 507ecf5e9ca6b606 in cluster 89c79295f798999a
2020-01-21 16:43:16.014763 E | rafthttp: failed to find member 507ecf5e9ca6b606 in cluster 89c79295f798999a
2020-01-21 16:43:16.014963 E | rafthttp: failed to find member 5c1954e5cd7a3e68 in cluster 89c79295f798999a

root@noded:/#
```

In the nodec container remove the old nodec data and make a directory for noded:

```
root@nodec:/# rm -rf nodec.etcd/

root@nodec:/# mkdir noded.etcd/

root@nodec:/#
```

Copy the noded member directory:

```
user@ubuntu:~$ docker container cp noded:noded.etcd/member/ .

user@ubuntu:~$ ls -l member/

total 8
drwx------ 2 root root 4096 Jan 30 00:26 snap
drwx------ 2 root root 4096 Jan 30 00:27 wal

user@ubuntu:~$ docker container cp member/ nodec:/noded.etcd/member/

user@ubuntu:~$
```

Confirm it was successful in the nodec container:

```
root@nodec:/#  ls -l  noded.etcd/member/

total 8
drwx------ 2 root root 4096 Jan 30 00:26 snap
drwx------ 2 root root 4096 Jan 30 00:27 wal

root@nodec:/#
```

Update the member information for noded for the new IP:

```
user@ubuntu:~$ etcdctl member list

173bccef55f1a2d8, started, noded, http://172.17.0.5:2380, http://172.17.0.5:2379, false
507ecf5e9ca6b606, started, nodeb, http://172.17.0.3:2380, http://172.17.0.3:2379, false
5c1954e5cd7a3e68, started, nodea, http://172.17.0.2:2380, http://172.17.0.2:2379, false

user@ubuntu:~$ etcdctl member update 173bccef55f1a2d8 --peer-urls=http://172.17.0.4:2380

Member 173bccef55f1a2d8 updated in cluster 89c79295f798999a

user@ubuntu:~$
```

Start the "new" noded in the nodec container:

```
root@c428a01f4fe9:/# etcd --name noded \
--initial-advertise-peer-urls http://172.17.0.4:2380 \
--listen-peer-urls http://172.17.0.4:2380 \
--listen-client-urls http://172.17.0.4:2379,http://127.0.0.1:2379 \
--advertise-client-urls http://172.17.0.4:2379 \
--initial-cluster-token cluster-1 \
--initial-cluster nodea=http://172.17.0.2:2380,nodeb=http://172.17.0.3:2380,noded=http://172.17.0.4:2380 \
--initial-cluster-state existing

2020-01-21 16:48:29.158325 I | etcdmain: etcd Version: 3.3.17
2020-01-21 16:48:29.158364 I | etcdmain: Git SHA: 6d8052314
2020-01-21 16:48:29.158367 I | etcdmain: Go Version: go1.12.9
2020-01-21 16:48:29.158370 I | etcdmain: Go OS/Arch: linux/amd64
2020-01-21 16:48:29.158372 I | etcdmain: setting maximum number of CPUs to 2, total number of available CPUs is 2
2020-01-21 16:48:29.158383 W | etcdmain: no data-dir provided, using default data-dir ./noded.etcd
2020-01-21 16:48:29.158428 N | etcdmain: the server is already initialized as member before, starting as etcd member...
2020-01-21 16:48:29.159009 I | embed: listening for peers on http://172.17.0.4:2380
2020-01-21 16:48:29.159055 I | embed: listening for client requests on 127.0.0.1:2379
2020-01-21 16:48:29.159131 I | embed: listening for client requests on 172.17.0.4:2379
2020-01-21 16:48:29.164611 I | etcdserver: name = noded
2020-01-21 16:48:29.164643 I | etcdserver: data dir = noded.etcd
2020-01-21 16:48:29.164647 I | etcdserver: member dir = noded.etcd/member
2020-01-21 16:48:29.164651 I | etcdserver: heartbeat = 100ms
2020-01-21 16:48:29.164674 I | etcdserver: election = 1000ms
2020-01-21 16:48:29.164677 I | etcdserver: snapshot count = 100000
2020-01-21 16:48:29.164705 I | etcdserver: advertise client URLs = http://172.17.0.4:2379
2020-01-21 16:48:29.172343 I | etcdserver: restarting member f225f6fe98c6b0e6 in cluster 89c79295f798999a at commit index 19
2020-01-21 16:48:29.172395 I | raft: f225f6fe98c6b0e6 became follower at term 149
2020-01-21 16:48:29.172403 I | raft: newRaft f225f6fe98c6b0e6 [peers: [], term: 149, commit: 19, applied: 0, lastindex: 19, lastterm: 149]
2020-01-21 16:48:29.180185 W | auth: simple token is not cryptographically signed
2020-01-21 16:48:29.180877 I | etcdserver: starting server... [version: 3.3.17, cluster version: to_be_decided]
2020-01-21 16:48:29.182298 I | etcdserver/membership: added member 507ecf5e9ca6b606 [http://172.17.0.3:2380] to cluster 89c79295f798999a
2020-01-21 16:48:29.182325 I | rafthttp: starting peer 507ecf5e9ca6b606...
2020-01-21 16:48:29.182362 I | rafthttp: started HTTP pipelining with peer 507ecf5e9ca6b606
2020-01-21 16:48:29.183878 I | rafthttp: started streaming with peer 507ecf5e9ca6b606 (writer)
2020-01-21 16:48:29.184095 I | rafthttp: started streaming with peer 507ecf5e9ca6b606 (writer)
2020-01-21 16:48:29.187427 I | rafthttp: started peer 507ecf5e9ca6b606
2020-01-21 16:48:29.187526 I | rafthttp: added peer 507ecf5e9ca6b606
2020-01-21 16:48:29.187790 I | etcdserver/membership: added member 5c1954e5cd7a3e68 [http://172.17.0.2:2380] to cluster 89c79295f798999a
2020-01-21 16:48:29.187955 I | rafthttp: started streaming with peer 507ecf5e9ca6b606 (stream MsgApp v2 reader)
2020-01-21 16:48:29.188399 I | rafthttp: started streaming with peer 507ecf5e9ca6b606 (stream Message reader)
2020-01-21 16:48:29.191483 I | rafthttp: starting peer 5c1954e5cd7a3e68...
2020-01-21 16:48:29.192145 I | rafthttp: started HTTP pipelining with peer 5c1954e5cd7a3e68
2020-01-21 16:48:29.192294 I | rafthttp: peer 507ecf5e9ca6b606 became active
2020-01-21 16:48:29.192315 I | rafthttp: established a TCP streaming connection with peer 507ecf5e9ca6b606 (stream MsgApp v2 reader)
2020-01-21 16:48:29.192342 I | rafthttp: established a TCP streaming connection with peer 507ecf5e9ca6b606 (stream MsgApp v2 writer)
2020-01-21 16:48:29.192347 I | rafthttp: established a TCP streaming connection with peer 507ecf5e9ca6b606 (stream Message reader)
2020-01-21 16:48:29.192943 I | rafthttp: started streaming with peer 5c1954e5cd7a3e68 (writer)
2020-01-21 16:48:29.193044 I | rafthttp: started streaming with peer 5c1954e5cd7a3e68 (writer)
2020-01-21 16:48:29.193538 I | rafthttp: started peer 5c1954e5cd7a3e68
2020-01-21 16:48:29.193555 I | rafthttp: added peer 5c1954e5cd7a3e68
2020-01-21 16:48:29.193912 I | etcdserver/membership: added member 69b68fd2de47b0f9 [http://172.17.0.4:2380] to cluster 89c79295f798999a
2020-01-21 16:48:29.193929 I | rafthttp: started streaming with peer 5c1954e5cd7a3e68 (stream MsgApp v2 reader)
2020-01-21 16:48:29.194078 I | rafthttp: started streaming with peer 5c1954e5cd7a3e68 (stream Message reader)
2020-01-21 16:48:29.194506 I | rafthttp: established a TCP streaming connection with peer 507ecf5e9ca6b606 (stream Message writer)
2020-01-21 16:48:29.194581 I | rafthttp: starting peer 69b68fd2de47b0f9...
2020-01-21 16:48:29.194640 I | rafthttp: started HTTP pipelining with peer 69b68fd2de47b0f9
2020-01-21 16:48:29.195110 I | rafthttp: started peer 69b68fd2de47b0f9
2020-01-21 16:48:29.195177 I | rafthttp: added peer 69b68fd2de47b0f9
2020-01-21 16:48:29.195306 I | rafthttp: peer 5c1954e5cd7a3e68 became active
2020-01-21 16:48:29.195348 I | rafthttp: established a TCP streaming connection with peer 5c1954e5cd7a3e68 (stream MsgApp v2 reader)
2020-01-21 16:48:29.195442 N | etcdserver/membership: set the initial cluster version to 3.0
2020-01-21 16:48:29.195521 I | etcdserver/api: enabled capabilities for version 3.0
2020-01-21 16:48:29.195640 I | rafthttp: started streaming with peer 69b68fd2de47b0f9 (stream MsgApp v2 reader)
2020-01-21 16:48:29.195766 I | rafthttp: started streaming with peer 69b68fd2de47b0f9 (stream Message reader)
2020-01-21 16:48:29.196443 N | etcdserver/membership: updated the cluster version from 3.0 to 3.3
2020-01-21 16:48:29.196568 I | etcdserver/api: enabled capabilities for version 3.3
2020-01-21 16:48:29.196727 I | etcdserver/membership: removed member 69b68fd2de47b0f9 from cluster 89c79295f798999a
2020-01-21 16:48:29.196774 I | rafthttp: stopping peer 69b68fd2de47b0f9...
2020-01-21 16:48:29.196810 I | rafthttp: started streaming with peer 69b68fd2de47b0f9 (writer)
2020-01-21 16:48:29.196817 I | rafthttp: stopped streaming with peer 69b68fd2de47b0f9 (writer)
2020-01-21 16:48:29.196825 I | rafthttp: started streaming with peer 69b68fd2de47b0f9 (writer)
2020-01-21 16:48:29.196828 I | rafthttp: stopped streaming with peer 69b68fd2de47b0f9 (writer)
2020-01-21 16:48:29.196837 I | rafthttp: stopped HTTP pipelining with peer 69b68fd2de47b0f9
2020-01-21 16:48:29.196850 I | rafthttp: stopped streaming with peer 69b68fd2de47b0f9 (stream MsgApp v2 reader)
2020-01-21 16:48:29.196913 I | rafthttp: stopped streaming with peer 69b68fd2de47b0f9 (stream Message reader)
2020-01-21 16:48:29.196918 I | rafthttp: stopped peer 69b68fd2de47b0f9
2020-01-21 16:48:29.196926 I | rafthttp: removed peer 69b68fd2de47b0f9
2020-01-21 16:48:29.196992 I | etcdserver/membership: added member 868f7f6f1f348543 [http://172.17.0.5:2380] to cluster 89c79295f798999a
2020-01-21 16:48:29.197023 I | rafthttp: starting peer 868f7f6f1f348543...
2020-01-21 16:48:29.197036 I | rafthttp: started HTTP pipelining with peer 868f7f6f1f348543
2020-01-21 16:48:29.197433 I | rafthttp: started peer 868f7f6f1f348543
2020-01-21 16:48:29.197923 I | rafthttp: established a TCP streaming connection with peer 5c1954e5cd7a3e68 (stream Message reader)
2020-01-21 16:48:29.197965 I | rafthttp: added peer 868f7f6f1f348543
2020-01-21 16:48:29.198216 I | etcdserver/membership: removed member 868f7f6f1f348543 from cluster 89c79295f798999a
2020-01-21 16:48:29.198245 I | rafthttp: stopping peer 868f7f6f1f348543...
2020-01-21 16:48:29.199514 I | rafthttp: started streaming with peer 868f7f6f1f348543 (writer)
2020-01-21 16:48:29.200432 I | rafthttp: stopped streaming with peer 868f7f6f1f348543 (writer)
2020-01-21 16:48:29.200456 I | rafthttp: started streaming with peer 868f7f6f1f348543 (writer)
2020-01-21 16:48:29.200461 I | rafthttp: stopped streaming with peer 868f7f6f1f348543 (writer)
2020-01-21 16:48:29.200477 I | rafthttp: started streaming with peer 868f7f6f1f348543 (stream MsgApp v2 reader)
2020-01-21 16:48:29.200621 I | rafthttp: stopped HTTP pipelining with peer 868f7f6f1f348543
2020-01-21 16:48:29.200645 I | rafthttp: stopped streaming with peer 868f7f6f1f348543 (stream MsgApp v2 reader)
2020-01-21 16:48:29.200660 I | rafthttp: started streaming with peer 868f7f6f1f348543 (stream Message reader)
2020-01-21 16:48:29.200673 I | rafthttp: stopped streaming with peer 868f7f6f1f348543 (stream Message reader)
2020-01-21 16:48:29.200677 I | rafthttp: stopped peer 868f7f6f1f348543
2020-01-21 16:48:29.200681 I | rafthttp: removed peer 868f7f6f1f348543
2020-01-21 16:48:29.200760 I | etcdserver/membership: added member f225f6fe98c6b0e6 [http://172.17.0.5:2380] to cluster 89c79295f798999a
2020-01-21 16:48:29.211256 I | rafthttp: established a TCP streaming connection with peer 5c1954e5cd7a3e68 (stream MsgApp v2 writer)
2020-01-21 16:48:29.211300 I | rafthttp: established a TCP streaming connection with peer 5c1954e5cd7a3e68 (stream Message writer)
2020-01-21 16:48:29.232156 I | etcdserver: f225f6fe98c6b0e6 initialzed peer connection; fast-forwarding 8 ticks (election ticks 10) with 2 active peer(s)
2020-01-21 16:48:29.252533 I | raft: raft.node: f225f6fe98c6b0e6 elected leader 5c1954e5cd7a3e68 at term 149
2020-01-21 16:48:29.253905 N | etcdserver/membership: updated member f225f6fe98c6b0e6 [http://172.17.0.4:2380] in cluster 89c79295f798999a
2020-01-21 16:48:29.254525 I | etcdserver: published {Name:noded ClientURLs:[http://172.17.0.4:2379]} to cluster 89c79295f798999a
2020-01-21 16:48:29.254579 I | embed: ready to serve client requests
2020-01-21 16:48:29.256261 N | embed: serving insecure client requests on 127.0.0.1:2379, this is strongly discouraged!
2020-01-21 16:48:29.256299 I | embed: ready to serve client requests
2020-01-21 16:48:29.257513 N | embed: serving insecure client requests on 172.17.0.4:2379, this is strongly discouraged!
```

Confirm the new noded is available:

```
user@ubuntu:~$ etcdctl member list

173bccef55f1a2d8, started, noded, http://172.17.0.4:2380, http://172.17.0.4:2379, false
507ecf5e9ca6b606, started, nodeb, http://172.17.0.3:2380, http://172.17.0.3:2379, false
5c1954e5cd7a3e68, started, nodea, http://172.17.0.2:2380, http://172.17.0.2:2379, false

user@ubuntu:~$  etcdctl get newvalue

newvalue
11111

user@ubuntu:~$
```


### 11. Cluster Backup and Restoration using etcdctl

etcdctl provides the `snapshot` subcommand which, which allows users to capture the current running state of the etcd
cluster and store it in a compressed file.

On your host VM, list the help for `etcdctl snapshot`:

```
user@ubuntu:~$ etcdctl snapshot --help
NAME:
	snapshot - Manages etcd node snapshots

USAGE:
	etcdctl snapshot <subcommand> [flags]

API VERSION:
	3.4


COMMANDS:
	restore	Restores an etcd member snapshot to an etcd directory
	save	Stores an etcd node backend snapshot to a given file
	status	Gets backend snapshot status of a given file

OPTIONS:
  -h, --help[=false]	help for snapshot

GLOBAL OPTIONS:
      --cacert=""				verify certificates of TLS-enabled secure servers using this CA bundle
      --cert=""					identify secure client using this TLS certificate file
      --command-timeout=5s			timeout for short running command (excluding dial timeout)
      --debug[=false]				enable client-side debug logging
      --dial-timeout=2s				dial timeout for client connections
  -d, --discovery-srv=""			domain name to query for SRV records describing cluster endpoints
      --discovery-srv-name=""			service name to query when using DNS discovery
      --endpoints=[127.0.0.1:2379]		gRPC endpoints
      --hex[=false]				print byte strings as hex encoded strings
      --insecure-discovery[=true]		accept insecure SRV records describing cluster endpoints
      --insecure-skip-tls-verify[=false]	skip server certificate verification
      --insecure-transport[=true]		disable transport security for client connections
      --keepalive-time=2s			keepalive time for client connections
      --keepalive-timeout=6s			keepalive timeout for client connections
      --key=""					identify secure client using this TLS key file
      --password=""				password for authentication (if this option is used, --user option shouldn't include password)
      --user=""					username[:password] for authentication (prompt if password is not supplied)
  -w, --write-out="simple"			set the output format (fields, json, protobuf, simple, table)

user@ubuntu:~$
```

`etcdctl snapshot` provides commands to restore a snapshot of a running etcd server into a fresh cluster. The three
operations it offers are:
- Creating snapshots of the etcd cluster keyspace
- Restoring snapshots of etcd members
- Verifying etcd snapshot contents

`etcdctl snapshot save` writes a point-in-time snapshot of the etcd backend database to a file. Users will copy this
file to a new node or the nodes that will replace members of the previous cluster the snapshot was taken from.

Create a backup of your current cluster using `etcdctl snapshot save`, selecting nodea as your target:

> N.B. In previous versions of ETCD you were able to use etcdctl snapshot save against your entire cluster. In 3.4, you
> must specify a single target host.

```
user@ubuntu:~$ unset ETCDCTL_ENDPOINTS

user@ubuntu:~$ etcdctl --endpoints 172.17.0.2:2379 snapshot save labcluster.db

{"level":"info","ts":1580344475.2612455,"caller":"snapshot/v3_snapshot.go:110","msg":"created temporary db file","path":"labcluster.db.part"}
{"level":"warn","ts":"2020-01-30T00:34:35.261Z","caller":"clientv3/retry_interceptor.go:116","msg":"retry stream intercept"}
{"level":"info","ts":1580344475.2618127,"caller":"snapshot/v3_snapshot.go:121","msg":"fetching snapshot","endpoint":"172.17.0.2:2379"}
{"level":"info","ts":1580344475.2663913,"caller":"snapshot/v3_snapshot.go:134","msg":"fetched snapshot","endpoint":"172.17.0.2:2379","took":0.005086036}
{"level":"info","ts":1580344475.2664506,"caller":"snapshot/v3_snapshot.go:143","msg":"saved","path":"labcluster.db"}

Snapshot saved at labcluster.db

user@ubuntu:~$
```

> N.B. If you are running etcd version 3.3.15, you will see an "retry stream intercept" error. You may safely ignore
> this error, the snapshot still saves successfully.

To verify your backup, you can use `etcdctl snapshot status`, which lists information about a given backend
database snapshot file. The data returned by `etcdctl snapshot status` includes:

- The hash of the backup, which `ectdctl snapshot restore` uses to verify the integrity of the backup
- The revision of the snapshot, which increments up when a snapshot is taken and new changes are detected
- The number of keys in the snapshot, representing the amount of key-value pairs inside the keyspace
- Size of the snapshot in kilobytes (kB)

```
user@ubuntu:~$ etcdctl snapshot status labcluster.db

313f89b2, 3, 9, 20 kB

user@ubuntu:~$
```

The information `etcdctl snapshot status` presents is sparse, but you can use the `--write-out` option to format the
output and add context to the snapshot.

Try to format the snapshot in a human readable table by using `--write-out table`:

```
user@ubuntu:~$ etcdctl snapshot status labcluster.db --write-out table

+----------+----------+------------+------------+
|   HASH   | REVISION | TOTAL KEYS | TOTAL SIZE |
+----------+----------+------------+------------+
| 313f89b2 |        3 |          9 |      20 kB |
+----------+----------+------------+------------+

user@ubuntu:~$
```

You can also output the same data in machine-readable JSON by using `write-out json`:

```
user@ubuntu:~$ etcdctl snapshot status labcluster.db --write-out json

{"hash":826247602,"revision":3,"totalKey":9,"totalSize":20480}

user@ubuntu:~$
```

Now that you have taken a snapshot of your current etcd cluster, it is time to distribute it to your nodes and restore
your cluster.

First, tear down the existing etcd members. Begin by removing the nodea member from the cluster using `etcdctl member
remove`:

```
user@ubuntu:~$ export ETCDCTL_ENDPOINTS=172.17.0.2:2379,172.17.0.3:2379,172.17.0.4:2379

user@ubuntu:~$ etcdctl member list

173bccef55f1a2d8, started, noded, http://172.17.0.4:2380, http://172.17.0.4:2379, false
507ecf5e9ca6b606, started, nodeb, http://172.17.0.3:2380, http://172.17.0.3:2379, false
5c1954e5cd7a3e68, started, nodea, http://172.17.0.2:2380, http://172.17.0.2:2379, false

user@ubuntu:~$ etcdctl member remove 5c1954e5cd7a3e68

Member 5c1954e5cd7a3e68 removed from cluster 89c79295f798999a

user@ubuntu:~$
```

Now tear down the `nodeb` and `noded` etcd processes with `CTRL C`. Leave the containers running:

```
^C

2020-01-21 16:53:26.162742 N | pkg/osutil: received interrupt signal, shutting down...
2020-01-21 16:53:26.162930 I | etcdserver: skipped leadership transfer for stopping non-leader member
WARNING: 2020/01/21 16:53:26 grpc: addrConn.createTransport failed to connect to {127.0.0.1:2379 0  <nil>}. Err :connection error: desc = "transport: Error while dialing dial tcp 127.0.0.1:2379: operation was canceled". Reconnecting...
2020-01-21 16:53:26.163073 I | rafthttp: stopping peer f225f6fe98c6b0e6...
2020-01-21 16:53:26.164209 I | rafthttp: closed the TCP streaming connection with peer f225f6fe98c6b0e6 (stream MsgApp v2 writer)
2020-01-21 16:53:26.164227 I | rafthttp: stopped streaming with peer f225f6fe98c6b0e6 (writer)
2020-01-21 16:53:26.164437 I | rafthttp: closed the TCP streaming connection with peer f225f6fe98c6b0e6 (stream Message writer)
2020-01-21 16:53:26.164490 I | rafthttp: stopped streaming with peer f225f6fe98c6b0e6 (writer)
2020-01-21 16:53:26.164504 I | rafthttp: stopped HTTP pipelining with peer f225f6fe98c6b0e6
2020-01-21 16:53:26.164534 W | rafthttp: lost the TCP streaming connection with peer f225f6fe98c6b0e6 (stream MsgApp v2 reader)
2020-01-21 16:53:26.164552 E | rafthttp: failed to read f225f6fe98c6b0e6 on stream MsgApp v2 (context canceled)
2020-01-21 16:53:26.164556 I | rafthttp: peer f225f6fe98c6b0e6 became inactive (message send to peer failed)
2020-01-21 16:53:26.164559 I | rafthttp: stopped streaming with peer f225f6fe98c6b0e6 (stream MsgApp v2 reader)
2020-01-21 16:53:26.164595 W | rafthttp: lost the TCP streaming connection with peer f225f6fe98c6b0e6 (stream Message reader)
2020-01-21 16:53:26.164599 I | rafthttp: stopped streaming with peer f225f6fe98c6b0e6 (stream Message reader)
2020-01-21 16:53:26.164603 I | rafthttp: stopped peer f225f6fe98c6b0e6

root@nodeb:/#
```

```
^C

2020-01-21 16:53:31.259106 N | pkg/osutil: received interrupt signal, shutting down...

...

2020-01-21 16:53:31.259621 I | rafthttp: stopped peer 507ecf5e9ca6b606

root@nodec:/#
```

A restore initializes a new member of a new cluster, with a fresh cluster configuration using etcd's cluster
configuration flags, but preserves the contents of the etcd keyspace. The restore will fail if an etcd member data
directory still exists on the new host.

Remove the etcd data directory from the nodea container:

```
user@ubuntu:~$ docker container exec nodea /bin/bash -c "rm -rf nodea.etcd"

user@ubuntu:~$
```

Use `ls` to confirm that the nodea.etcd directory was deleted:

```
user@ubuntu:~$ docker container exec nodea /bin/bash -c "ls -l"

total 64
drwxr-xr-x   2 root root 4096 Jan 14 16:52 bin
drwxr-xr-x   2 root root 4096 Apr 12  2016 boot
drwxr-xr-x   5 root root  360 Jan 21 15:55 dev
drwxr-xr-x   1 root root 4096 Jan 21 15:55 etc
drwxr-xr-x   2 root root 4096 Apr 12  2016 home
drwxr-xr-x   8 root root 4096 Sep 13  2015 lib
drwxr-xr-x   2 root root 4096 Jan 14 16:52 lib64
drwxr-xr-x   2 root root 4096 Jan 14 16:51 media
drwxr-xr-x   2 root root 4096 Jan 14 16:51 mnt
drwxr-xr-x   2 root root 4096 Jan 14 16:51 opt
dr-xr-xr-x 250 root root    0 Jan 21 15:55 proc
drwx------   2 root root 4096 Jan 14 16:52 root
drwxr-xr-x   1 root root 4096 Jan 14 16:52 run
drwxr-xr-x   1 root root 4096 Jan 16 01:21 sbin
drwxr-xr-x   2 root root 4096 Jan 14 16:51 srv
dr-xr-xr-x  13 root root    0 Jan 21 16:39 sys
drwxrwxrwt   2 root root 4096 Jan 14 16:52 tmp
drwxr-xr-x   1 root root 4096 Jan 14 16:51 usr
drwxr-xr-x   1 root root 4096 Jan 14 16:52 var

user@ubuntu:~$
```

Delete the etcd directories from nodes B and C:

```
user@ubuntu:~$ docker container exec nodeb /bin/bash -c "rm -rf nodeb.etcd"

user@ubuntu:~$ docker container exec nodec /bin/bash -c "rm -rf noded.etcd"

user@ubuntu:~$
```

The snapshot restoration process is driven by etcdctl, so in order to perform the restoration you need have etcdctl
available on the member node you wish to restore.

Copy etcdctl to each of the containers:

```
user@ubuntu:~$ docker container cp etcd/etcdctl nodea:/usr/bin/etcdctl

user@ubuntu:~$
```

Confirm that etcdctl is now available on the nodea container by using `docker exec` to list the help:

```
user@ubuntu:~$ docker container exec nodea etcdctl --help

NAME:
   etcdctl - A simple command line client for etcd.

WARNING:
   Environment variable ETCDCTL_API is not set; defaults to etcdctl v2.
   Set environment variable ETCDCTL_API=3 to use v3 API or ETCDCTL_API=2 to use v2 API.

USAGE:
   etcdctl [global options] command [command options] [arguments...]

VERSION:
   3.3.17

COMMANDS:
     backup          backup an etcd directory
     cluster-health  check the health of the etcd cluster
     mk              make a new key with a given value
     mkdir           make a new directory
     rm              remove a key or a directory
     rmdir           removes the key if it is an empty directory or a key-value pair
     get             retrieve the value of a key
     ls              retrieve a directory
     set             set the value of a key
     setdir          create a new directory or update an existing directory TTL
     update          update an existing key with a given value
     updatedir       update an existing directory
     watch           watch a key for changes
     exec-watch      watch a key for changes and exec an executable
     member          member add, remove and list subcommands
     user            user add, grant and revoke subcommands
     role            role add, grant and revoke subcommands
     auth            overall auth controls
     help, h         Shows a list of commands or help for one command

GLOBAL OPTIONS:
   --debug                          output cURL commands which can be used to reproduce the request
   --no-sync                        don't synchronize cluster information before sending request
   --output simple, -o simple       output response in the given format (simple, `extended` or `json`) (default: "simple")
   --discovery-srv value, -D value  domain name to query for SRV records describing cluster endpoints
   --insecure-discovery             accept insecure SRV records describing cluster endpoints
   --peers value, -C value          DEPRECATED - "--endpoints" should be used instead
   --endpoint value                 DEPRECATED - "--endpoints" should be used instead
   --endpoints value                a comma-delimited list of machine addresses in the cluster (default: "http://127.0.0.1:2379,http://127.0.0.1:4001")
   --cert-file value                identify HTTPS client using this SSL certificate file
   --key-file value                 identify HTTPS client using this SSL key file
   --ca-file value                  verify certificates of HTTPS-enabled servers using this CA bundle
   --username value, -u value       provide username[:password] and prompt if password is not supplied.
   --timeout value                  connection timeout per request (default: 2s)
   --total-timeout value            timeout for the command execution (except watch) (default: 5s)
   --help, -h                       show help
   --version, -v                    print the version

user@ubuntu:~$
```

nodea can successfully invoke the etcdctl tool.

Copy etcdctl to the nodeb and nodec containers:

```
user@ubuntu:~$ docker container cp etcd/etcdctl nodeb:/usr/bin/etcdctl

user@ubuntu:~$ docker container cp etcd/etcdctl nodec:/usr/bin/etcdctl

user@ubuntu:~$
```

Your nodes are now ready to restore the cluster on them. Distribute the snapshot each of your new nodes.

Copy the snapshot to nodea and use `ls` to make sure it is present under the container's `/tmp` directory:

```
user@ubuntu:~$ docker container cp labcluster.db nodea:/tmp/labcluster.db

user@ubuntu:~$ docker container exec nodea ls -l /tmp

total 24
-rw-rw-r-- 1 1000 1000 20512 Jan 21 16:51 labcluster.db

user@ubuntu:~$
```

After confirming that the snapshot file is present on the node, continue distributing the backup.

Copy the snapshot to nodeb and nodec:

```
user@ubuntu:~$ docker container cp labcluster.db nodeb:/tmp/labcluster.db

user@ubuntu:~$ docker container cp labcluster.db nodec:/tmp/labcluster.db

user@ubuntu:~$ docker container exec nodeb ls -l /tmp

total 24
-rw-rw-r-- 1 1000 1000 20512 Jan 21 16:51 labcluster.db

user@ubuntu:~$ docker container exec nodec ls -l /tmp

total 24
-rw-rw-r-- 1 1000 1000 20512 Jan 21 16:51 labcluster.db

user@ubuntu:~$
```

The etcd cluster backup process must create a new logical cluster. You will need to provide the addresses of the etcd
instances (found on port 2380), a cluster token, and tell what the returning node's ip should be.

In your nodea terminal, use etcdctl to restore the snapshot. Be sure to identify nodea, nodeb, and noded in the
`initial-cluster` option, and provide the etcd member's IP address for the `initial-advertise-peer-urls` option:

```
root@nodea:/# ETCDCTL_API=3 etcdctl snapshot restore /tmp/labcluster.db \
--name nodea \
--initial-advertise-peer-urls http://172.17.0.2:2380 \
--initial-cluster nodea=http://172.17.0.2:2380,nodeb=http://172.17.0.3:2380,noded=http://172.17.0.4:2380 \
--initial-cluster-token cluster-1

2020-01-21 16:58:10.715466 I | etcdserver/membership: added member 507ecf5e9ca6b606 [http://172.17.0.3:2380] to cluster 89c79295f798999a
2020-01-21 16:58:10.715528 I | etcdserver/membership: added member 5c1954e5cd7a3e68 [http://172.17.0.2:2380] to cluster 89c79295f798999a
2020-01-21 16:58:10.715540 I | etcdserver/membership: added member 69b68fd2de47b0f9 [http://172.17.0.4:2380] to cluster 89c79295f798999a

root@nodea:/#
```

`etcdctl snapshot restore` creates an etcd data directory for an etcd cluster member from a database snapshot file and
creates a new cluster configuration. Restoring the snapshot into each member for a new cluster configuration will
initialize a new etcd cluster preloaded by the snapshot data. All members must be restored using the same snapshot.

Use `ls` to check if a new etcd member node directory is present:

```
root@nodea:/# ls -l

total 68
drwxr-xr-x   2 root root 4096 Jan 14 16:52 bin
drwxr-xr-x   2 root root 4096 Apr 12  2016 boot
drwxr-xr-x   5 root root  360 Jan 21 15:55 dev
drwxr-xr-x   1 root root 4096 Jan 21 15:55 etc
drwxr-xr-x   2 root root 4096 Apr 12  2016 home
drwxr-xr-x   8 root root 4096 Sep 13  2015 lib
drwxr-xr-x   2 root root 4096 Jan 14 16:52 lib64
drwxr-xr-x   2 root root 4096 Jan 14 16:51 media
drwxr-xr-x   2 root root 4096 Jan 14 16:51 mnt
drwx------   3 root root 4096 Jan 21 16:58 nodea.etcd
drwxr-xr-x   2 root root 4096 Jan 14 16:51 opt
dr-xr-xr-x 249 root root    0 Jan 21 15:55 proc
drwx------   2 root root 4096 Jan 14 16:52 root
drwxr-xr-x   1 root root 4096 Jan 14 16:52 run
drwxr-xr-x   1 root root 4096 Jan 16 01:21 sbin
drwxr-xr-x   2 root root 4096 Jan 14 16:51 srv
dr-xr-xr-x  13 root root    0 Jan 21 16:39 sys
drwxrwxrwt   1 root root 4096 Jan 21 16:56 tmp
drwxr-xr-x   1 root root 4096 Jan 14 16:51 usr
drwxr-xr-x   1 root root 4096 Jan 14 16:52 var

root@nodea:/#
```

A new folder on the nodea container, nodea.etcd, is now present. List the contents of the nodea directory with `ls`,
passing the `-R` switch to recursively list the contents of the directory:

```
root@nodea:/# ls -l -R *.etcd

nodea.etcd:
total 4
drwx------ 4 root root 4096 Jan 21 16:58 member

nodea.etcd/member:
total 8
drwx------ 2 root root 4096 Jan 21 16:58 snap
drwx------ 2 root root 4096 Jan 21 16:58 wal

nodea.etcd/member/snap:
total 28
-rw-r--r-- 1 root root  7567 Jan 21 16:58 0000000000000001-0000000000000003.snap
-rw------- 1 root root 20480 Jan 21 16:58 db

nodea.etcd/member/wal:
total 62500
-rw------- 1 root root 64000000 Jan 21 16:58 0000000000000000-0000000000000000.wal

root@nodea:/#
```

Start the etcd instance on the nodea container again. Use the same options from your initial start, but change the
`initial-cluster-state` value to `existing` and once more make sure that you refer to noded in the `initial-cluster`
listing (you can use the same --initial-cluster option from the `etcdctl snapshot restore` command):

```
root@nodea:/# etcd --name nodea --initial-advertise-peer-urls http://172.17.0.2:2380 \
--listen-peer-urls http://172.17.0.2:2380 \
--listen-client-urls http://172.17.0.2:2379,http://127.0.0.1:2379 \
--advertise-client-urls http://172.17.0.2:2379 \
--initial-cluster-token cluster-1 \
--initial-cluster nodea=http://172.17.0.2:2380,nodeb=http://172.17.0.3:2380,noded=http://172.17.0.4:2380 \
--initial-cluster-state existing

2020-01-21 16:59:09.982296 I | etcdmain: etcd Version: 3.3.17
2020-01-21 16:59:09.982333 I | etcdmain: Git SHA: 6d8052314
2020-01-21 16:59:09.982337 I | etcdmain: Go Version: go1.12.9
2020-01-21 16:59:09.982339 I | etcdmain: Go OS/Arch: linux/amd64
2020-01-21 16:59:09.982341 I | etcdmain: setting maximum number of CPUs to 2, total number of available CPUs is 2
2020-01-21 16:59:09.982346 W | etcdmain: no data-dir provided, using default data-dir ./nodea.etcd
2020-01-21 16:59:09.982386 N | etcdmain: the server is already initialized as member before, starting as etcd member...
2020-01-21 16:59:09.982493 I | embed: listening for peers on http://172.17.0.2:2380
2020-01-21 16:59:09.982542 I | embed: listening for client requests on 127.0.0.1:2379
2020-01-21 16:59:09.982567 I | embed: listening for client requests on 172.17.0.2:2379
2020-01-21 16:59:09.983554 I | etcdserver: recovered store from snapshot at index 3
2020-01-21 16:59:09.984593 I | etcdserver: name = nodea
2020-01-21 16:59:09.984617 I | etcdserver: data dir = nodea.etcd
2020-01-21 16:59:09.984622 I | etcdserver: member dir = nodea.etcd/member
2020-01-21 16:59:09.984634 I | etcdserver: heartbeat = 100ms
2020-01-21 16:59:09.984637 I | etcdserver: election = 1000ms
2020-01-21 16:59:09.984639 I | etcdserver: snapshot count = 100000
2020-01-21 16:59:09.984646 I | etcdserver: advertise client URLs = http://172.17.0.2:2379
2020-01-21 16:59:09.985101 I | etcdserver: restarting member 5c1954e5cd7a3e68 in cluster 89c79295f798999a at commit index 3
2020-01-21 16:59:09.985136 I | raft: 5c1954e5cd7a3e68 became follower at term 1
2020-01-21 16:59:09.985145 I | raft: newRaft 5c1954e5cd7a3e68 [peers: [507ecf5e9ca6b606,5c1954e5cd7a3e68,69b68fd2de47b0f9], term: 1, commit: 3, applied: 3, lastindex: 3, lastterm: 1]
2020-01-21 16:59:09.985227 I | etcdserver/membership: added member 507ecf5e9ca6b606 [http://172.17.0.3:2380] to cluster 89c79295f798999a from store
2020-01-21 16:59:09.985233 I | etcdserver/membership: added member 5c1954e5cd7a3e68 [http://172.17.0.2:2380] to cluster 89c79295f798999a from store
2020-01-21 16:59:09.985239 I | etcdserver/membership: added member 69b68fd2de47b0f9 [http://172.17.0.4:2380] to cluster 89c79295f798999a from store
2020-01-21 16:59:09.986426 W | auth: simple token is not cryptographically signed
2020-01-21 16:59:09.986912 I | rafthttp: starting peer 507ecf5e9ca6b606...
2020-01-21 16:59:09.986953 I | rafthttp: started HTTP pipelining with peer 507ecf5e9ca6b606
2020-01-21 16:59:09.987429 I | rafthttp: started streaming with peer 507ecf5e9ca6b606 (writer)
2020-01-21 16:59:09.989101 I | rafthttp: started peer 507ecf5e9ca6b606
2020-01-21 16:59:09.989136 I | rafthttp: added peer 507ecf5e9ca6b606
2020-01-21 16:59:09.989147 I | rafthttp: starting peer 69b68fd2de47b0f9...
2020-01-21 16:59:09.989157 I | rafthttp: started HTTP pipelining with peer 69b68fd2de47b0f9
2020-01-21 16:59:09.990195 I | rafthttp: started streaming with peer 507ecf5e9ca6b606 (stream Message reader)
2020-01-21 16:59:09.990546 I | rafthttp: started peer 69b68fd2de47b0f9
2020-01-21 16:59:09.990578 I | rafthttp: added peer 69b68fd2de47b0f9
2020-01-21 16:59:09.990586 I | etcdserver: starting server... [version: 3.3.17, cluster version: to_be_decided]
2020-01-21 16:59:09.990602 I | rafthttp: started streaming with peer 507ecf5e9ca6b606 (writer)
2020-01-21 16:59:09.990682 I | rafthttp: started streaming with peer 507ecf5e9ca6b606 (stream MsgApp v2 reader)
2020-01-21 16:59:09.991481 I | rafthttp: started streaming with peer 69b68fd2de47b0f9 (writer)
2020-01-21 16:59:09.991503 I | rafthttp: started streaming with peer 69b68fd2de47b0f9 (writer)
2020-01-21 16:59:09.991532 I | rafthttp: started streaming with peer 69b68fd2de47b0f9 (stream MsgApp v2 reader)
2020-01-21 16:59:09.991650 I | rafthttp: started streaming with peer 69b68fd2de47b0f9 (stream Message reader)
2020-01-21 16:59:11.286010 I | raft: 5c1954e5cd7a3e68 is starting a new election at term 1

...

```

Perform the restorations for nodeb, then start the nodeb etcd member:

```
root@nodeb:/# ETCDCTL_API=3 etcdctl snapshot restore /tmp/labcluster.db \
--name nodeb \
--initial-cluster nodea=http://172.17.0.2:2380,nodeb=http://172.17.0.3:2380,noded=http://172.17.0.4:2380 \
--initial-cluster-token cluster-1 \
--initial-advertise-peer-urls http://172.17.0.3:2380

2020-01-21 17:00:04.817914 I | etcdserver/membership: added member 507ecf5e9ca6b606 [http://172.17.0.3:2380] to cluster 89c79295f798999a
2020-01-21 17:00:04.817956 I | etcdserver/membership: added member 5c1954e5cd7a3e68 [http://172.17.0.2:2380] to cluster 89c79295f798999a
2020-01-21 17:00:04.817965 I | etcdserver/membership: added member 69b68fd2de47b0f9 [http://172.17.0.4:2380] to cluster 89c79295f798999a

root@nodeb:/# etcd \
--name nodeb \
--initial-advertise-peer-urls http://172.17.0.3:2380 \
--listen-peer-urls http://172.17.0.3:2380 \
--listen-client-urls http://172.17.0.3:2379,http://127.0.0.1:2379 \
--advertise-client-urls http://172.17.0.3:2379 \
--initial-cluster-token cluster-1 \
--initial-cluster nodea=http://172.17.0.2:2380,nodeb=http://172.17.0.3:2380,noded=http://172.17.0.4:2380 \
--initial-cluster-state existing

2020-01-21 17:00:20.367957 I | etcdmain: etcd Version: 3.3.17
2020-01-21 17:00:20.368004 I | etcdmain: Git SHA: 6d8052314
2020-01-21 17:00:20.368007 I | etcdmain: Go Version: go1.12.9
2020-01-21 17:00:20.368010 I | etcdmain: Go OS/Arch: linux/amd64
2020-01-21 17:00:20.368012 I | etcdmain: setting maximum number of CPUs to 2, total number of available CPUs is 2
2020-01-21 17:00:20.368017 W | etcdmain: no data-dir provided, using default data-dir ./nodeb.etcd
2020-01-21 17:00:20.368094 N | etcdmain: the server is already initialized as member before, starting as etcd member...
2020-01-21 17:00:20.368219 I | embed: listening for peers on http://172.17.0.3:2380
2020-01-21 17:00:20.368260 I | embed: listening for client requests on 127.0.0.1:2379
2020-01-21 17:00:20.368271 I | embed: listening for client requests on 172.17.0.3:2379
2020-01-21 17:00:20.370806 I | etcdserver: recovered store from snapshot at index 3
2020-01-21 17:00:20.371721 I | etcdserver: name = nodeb
2020-01-21 17:00:20.371746 I | etcdserver: data dir = nodeb.etcd
2020-01-21 17:00:20.371751 I | etcdserver: member dir = nodeb.etcd/member
2020-01-21 17:00:20.371753 I | etcdserver: heartbeat = 100ms
2020-01-21 17:00:20.371755 I | etcdserver: election = 1000ms
2020-01-21 17:00:20.371757 I | etcdserver: snapshot count = 100000
2020-01-21 17:00:20.371824 I | etcdserver: advertise client URLs = http://172.17.0.3:2379
2020-01-21 17:00:20.375694 I | etcdserver: restarting member 507ecf5e9ca6b606 in cluster 89c79295f798999a at commit index 3
2020-01-21 17:00:20.375736 I | raft: 507ecf5e9ca6b606 became follower at term 1
2020-01-21 17:00:20.375745 I | raft: newRaft 507ecf5e9ca6b606 [peers: [507ecf5e9ca6b606,5c1954e5cd7a3e68,69b68fd2de47b0f9], term: 1, commit: 3, applied: 3, lastindex: 3, lastterm: 1]
2020-01-21 17:00:20.375900 I | etcdserver/membership: added member 507ecf5e9ca6b606 [http://172.17.0.3:2380] to cluster 89c79295f798999a from store
2020-01-21 17:00:20.375919 I | etcdserver/membership: added member 5c1954e5cd7a3e68 [http://172.17.0.2:2380] to cluster 89c79295f798999a from store
2020-01-21 17:00:20.375923 I | etcdserver/membership: added member 69b68fd2de47b0f9 [http://172.17.0.4:2380] to cluster 89c79295f798999a from store
2020-01-21 17:00:20.377147 W | auth: simple token is not cryptographically signed
2020-01-21 17:00:20.378135 I | rafthttp: starting peer 5c1954e5cd7a3e68...
2020-01-21 17:00:20.378303 I | rafthttp: started HTTP pipelining with peer 5c1954e5cd7a3e68
2020-01-21 17:00:20.380955 I | rafthttp: started streaming with peer 5c1954e5cd7a3e68 (writer)
2020-01-21 17:00:20.385715 I | rafthttp: started streaming with peer 5c1954e5cd7a3e68 (writer)
2020-01-21 17:00:20.389626 I | rafthttp: started peer 5c1954e5cd7a3e68
2020-01-21 17:00:20.391390 I | rafthttp: added peer 5c1954e5cd7a3e68
2020-01-21 17:00:20.391418 I | rafthttp: starting peer 69b68fd2de47b0f9...
2020-01-21 17:00:20.391526 I | rafthttp: started HTTP pipelining with peer 69b68fd2de47b0f9
2020-01-21 17:00:20.392030 I | rafthttp: started streaming with peer 5c1954e5cd7a3e68 (stream Message reader)
2020-01-21 17:00:20.392057 I | rafthttp: started streaming with peer 5c1954e5cd7a3e68 (stream MsgApp v2 reader)
2020-01-21 17:00:20.399322 I | rafthttp: started peer 69b68fd2de47b0f9
2020-01-21 17:00:20.399367 I | rafthttp: added peer 69b68fd2de47b0f9
2020-01-21 17:00:20.399378 I | etcdserver: starting server... [version: 3.3.17, cluster version: to_be_decided]
2020-01-21 17:00:20.401230 I | rafthttp: started streaming with peer 69b68fd2de47b0f9 (writer)
2020-01-21 17:00:20.401254 I | rafthttp: started streaming with peer 69b68fd2de47b0f9 (writer)
2020-01-21 17:00:20.401270 I | rafthttp: started streaming with peer 69b68fd2de47b0f9 (stream MsgApp v2 reader)
2020-01-21 17:00:20.402347 I | rafthttp: started streaming with peer 69b68fd2de47b0f9 (stream Message reader)
2020-01-21 17:00:20.403879 I | rafthttp: peer 5c1954e5cd7a3e68 became active
2020-01-21 17:00:20.403890 I | rafthttp: established a TCP streaming connection with peer 5c1954e5cd7a3e68 (stream MsgApp v2 reader)
2020-01-21 17:00:20.409160 I | rafthttp: established a TCP streaming connection with peer 5c1954e5cd7a3e68 (stream Message reader)
2020-01-21 17:00:20.457962 I | rafthttp: established a TCP streaming connection with peer 5c1954e5cd7a3e68 (stream Message writer)
2020-01-21 17:00:20.458643 I | rafthttp: established a TCP streaming connection with peer 5c1954e5cd7a3e68 (stream MsgApp v2 writer)
2020-01-21 17:00:21.050472 I | raft: 507ecf5e9ca6b606 [term: 1] received a MsgVote message with higher term from 5c1954e5cd7a3e68 [term: 51]
2020-01-21 17:00:21.050489 I | raft: 507ecf5e9ca6b606 became follower at term 51
2020-01-21 17:00:21.050495 I | raft: 507ecf5e9ca6b606 [logterm: 1, index: 3, vote: 0] cast MsgVote for 5c1954e5cd7a3e68 [logterm: 1, index: 3] at term 51
2020-01-21 17:00:21.051109 I | raft: raft.node: 507ecf5e9ca6b606 elected leader 5c1954e5cd7a3e68 at term 51
2020-01-21 17:00:21.052404 I | etcdserver: published {Name:nodeb ClientURLs:[http://172.17.0.3:2379]} to cluster 89c79295f798999a
2020-01-21 17:00:21.052447 I | embed: ready to serve client requests
2020-01-21 17:00:21.052569 I | embed: ready to serve client requests
2020-01-21 17:00:21.053014 N | embed: serving insecure client requests on 172.17.0.3:2379, this is strongly discouraged!
2020-01-21 17:00:21.053041 N | embed: serving insecure client requests on 127.0.0.1:2379, this is strongly discouraged!
2020-01-21 17:00:21.054219 N | etcdserver/membership: set the initial cluster version to 3.0
2020-01-21 17:00:21.054295 I | etcdserver/api: enabled capabilities for version 3.0

```

Finally, perform the restoration and bootstrap of noded (hosted on nodec):

```
root@nodec:/# ETCDCTL_API=3 etcdctl snapshot restore /tmp/labcluster.db \
--name noded \
--initial-cluster nodea=http://172.17.0.2:2380,nodeb=http://172.17.0.3:2380,noded=http://172.17.0.4:2380 \
--initial-cluster-token cluster-1 \
--initial-advertise-peer-urls http://172.17.0.4:2380

2020-01-21 17:00:49.285395 I | etcdserver/membership: added member 507ecf5e9ca6b606 [http://172.17.0.3:2380] to cluster 89c79295f798999a
2020-01-21 17:00:49.285446 I | etcdserver/membership: added member 5c1954e5cd7a3e68 [http://172.17.0.2:2380] to cluster 89c79295f798999a
2020-01-21 17:00:49.285458 I | etcdserver/membership: added member 69b68fd2de47b0f9 [http://172.17.0.4:2380] to cluster 89c79295f798999a

root@nodec:/# etcd --name noded \
--initial-advertise-peer-urls http://172.17.0.4:2380 \
--listen-peer-urls http://172.17.0.4:2380 \
--listen-client-urls http://172.17.0.4:2379,http://127.0.0.1:2379 \
--advertise-client-urls http://172.17.0.4:2379 \
--initial-cluster-token cluster-1 \
--initial-cluster nodea=http://172.17.0.2:2380,nodeb=http://172.17.0.3:2380,noded=http://172.17.0.4:2380 \
--initial-cluster-state existing

2020-01-21 17:02:11.292959 I | etcdmain: etcd Version: 3.3.17
2020-01-21 17:02:11.292995 I | etcdmain: Git SHA: 6d8052314
2020-01-21 17:02:11.292999 I | etcdmain: Go Version: go1.12.9
2020-01-21 17:02:11.293001 I | etcdmain: Go OS/Arch: linux/amd64
2020-01-21 17:02:11.293003 I | etcdmain: setting maximum number of CPUs to 2, total number of available CPUs is 2
2020-01-21 17:02:11.293007 W | etcdmain: no data-dir provided, using default data-dir ./noded.etcd
2020-01-21 17:02:11.293113 N | etcdmain: the server is already initialized as member before, starting as etcd member...
2020-01-21 17:02:11.293190 I | embed: listening for peers on http://172.17.0.4:2380
2020-01-21 17:02:11.293261 I | embed: listening for client requests on 127.0.0.1:2379
2020-01-21 17:02:11.293272 I | embed: listening for client requests on 172.17.0.4:2379
2020-01-21 17:02:11.294273 I | etcdserver: recovered store from snapshot at index 3
2020-01-21 17:02:11.294828 I | etcdserver: name = noded
2020-01-21 17:02:11.294848 I | etcdserver: data dir = noded.etcd
2020-01-21 17:02:11.294852 I | etcdserver: member dir = noded.etcd/member
2020-01-21 17:02:11.294854 I | etcdserver: heartbeat = 100ms
2020-01-21 17:02:11.294916 I | etcdserver: election = 1000ms
2020-01-21 17:02:11.294920 I | etcdserver: snapshot count = 100000
2020-01-21 17:02:11.294926 I | etcdserver: advertise client URLs = http://172.17.0.4:2379
2020-01-21 17:02:11.295983 I | etcdserver: restarting member 69b68fd2de47b0f9 in cluster 89c79295f798999a at commit index 3
2020-01-21 17:02:11.296330 I | raft: 69b68fd2de47b0f9 became follower at term 1
2020-01-21 17:02:11.296357 I | raft: newRaft 69b68fd2de47b0f9 [peers: [507ecf5e9ca6b606,5c1954e5cd7a3e68,69b68fd2de47b0f9], term: 1, commit: 3, applied: 3, lastindex: 3, lastterm: 1]
2020-01-21 17:02:11.296558 I | etcdserver/membership: added member 507ecf5e9ca6b606 [http://172.17.0.3:2380] to cluster 89c79295f798999a from store
2020-01-21 17:02:11.296665 I | etcdserver/membership: added member 5c1954e5cd7a3e68 [http://172.17.0.2:2380] to cluster 89c79295f798999a from store
2020-01-21 17:02:11.296744 I | etcdserver/membership: added member 69b68fd2de47b0f9 [http://172.17.0.4:2380] to cluster 89c79295f798999a from store
2020-01-21 17:02:11.302488 W | auth: simple token is not cryptographically signed
2020-01-21 17:02:11.303417 I | rafthttp: starting peer 507ecf5e9ca6b606...
2020-01-21 17:02:11.303527 I | rafthttp: started HTTP pipelining with peer 507ecf5e9ca6b606
2020-01-21 17:02:11.308457 I | rafthttp: started streaming with peer 507ecf5e9ca6b606 (writer)
2020-01-21 17:02:11.309684 I | rafthttp: started peer 507ecf5e9ca6b606
2020-01-21 17:02:11.309724 I | rafthttp: added peer 507ecf5e9ca6b606
2020-01-21 17:02:11.309736 I | rafthttp: starting peer 5c1954e5cd7a3e68...
2020-01-21 17:02:11.309832 I | rafthttp: started HTTP pipelining with peer 5c1954e5cd7a3e68
2020-01-21 17:02:11.309989 I | rafthttp: started streaming with peer 507ecf5e9ca6b606 (writer)
2020-01-21 17:02:11.310061 I | rafthttp: started streaming with peer 507ecf5e9ca6b606 (stream MsgApp v2 reader)
2020-01-21 17:02:11.311255 I | rafthttp: started peer 5c1954e5cd7a3e68
2020-01-21 17:02:11.311277 I | rafthttp: added peer 5c1954e5cd7a3e68
2020-01-21 17:02:11.311288 I | etcdserver: starting server... [version: 3.3.17, cluster version: to_be_decided]
2020-01-21 17:02:11.311893 I | rafthttp: started streaming with peer 5c1954e5cd7a3e68 (writer)
2020-01-21 17:02:11.311923 I | rafthttp: started streaming with peer 507ecf5e9ca6b606 (stream Message reader)
2020-01-21 17:02:11.312200 I | rafthttp: started streaming with peer 5c1954e5cd7a3e68 (writer)
2020-01-21 17:02:11.313643 I | rafthttp: started streaming with peer 5c1954e5cd7a3e68 (stream MsgApp v2 reader)
2020-01-21 17:02:11.314229 I | rafthttp: started streaming with peer 5c1954e5cd7a3e68 (stream Message reader)
2020-01-21 17:02:11.318076 I | rafthttp: peer 507ecf5e9ca6b606 became active
2020-01-21 17:02:11.318908 I | rafthttp: established a TCP streaming connection with peer 507ecf5e9ca6b606 (stream MsgApp v2 writer)
2020-01-21 17:02:11.323589 I | rafthttp: established a TCP streaming connection with peer 507ecf5e9ca6b606 (stream MsgApp v2 reader)
2020-01-21 17:02:11.324509 I | rafthttp: peer 5c1954e5cd7a3e68 became active
2020-01-21 17:02:11.324546 I | rafthttp: established a TCP streaming connection with peer 5c1954e5cd7a3e68 (stream Message reader)
2020-01-21 17:02:11.324583 I | rafthttp: established a TCP streaming connection with peer 507ecf5e9ca6b606 (stream Message reader)
2020-01-21 17:02:11.324604 I | rafthttp: established a TCP streaming connection with peer 5c1954e5cd7a3e68 (stream MsgApp v2 reader)
2020-01-21 17:02:11.325666 I | rafthttp: established a TCP streaming connection with peer 507ecf5e9ca6b606 (stream Message writer)
2020-01-21 17:02:11.349255 I | raft: 69b68fd2de47b0f9 [term: 1] received a MsgHeartbeat message with higher term from 5c1954e5cd7a3e68 [term: 51]
2020-01-21 17:02:11.349287 I | raft: 69b68fd2de47b0f9 became follower at term 51
2020-01-21 17:02:11.349294 I | raft: raft.node: 69b68fd2de47b0f9 elected leader 5c1954e5cd7a3e68 at term 51
2020-01-21 17:02:11.354083 N | etcdserver/membership: set the initial cluster version to 3.0
2020-01-21 17:02:11.354618 I | etcdserver/api: enabled capabilities for version 3.0
2020-01-21 17:02:11.356422 I | etcdserver: published {Name:noded ClientURLs:[http://172.17.0.4:2379]} to cluster 89c79295f798999a
2020-01-21 17:02:11.357087 I | embed: ready to serve client requests
2020-01-21 17:02:11.357939 N | embed: serving insecure client requests on 127.0.0.1:2379, this is strongly discouraged!
2020-01-21 17:02:11.357983 I | embed: ready to serve client requests
2020-01-21 17:02:11.358227 N | embed: serving insecure client requests on 172.17.0.4:2379, this is strongly discouraged!
2020-01-21 17:02:11.359754 I | rafthttp: established a TCP streaming connection with peer 5c1954e5cd7a3e68 (stream MsgApp v2 writer)
2020-01-21 17:02:11.360319 I | rafthttp: established a TCP streaming connection with peer 5c1954e5cd7a3e68 (stream Message writer)
2020-01-21 17:02:11.375634 I | etcdserver: 69b68fd2de47b0f9 initialzed peer connection; fast-forwarding 8 ticks (election ticks 10) with 2 active peer(s)

```

With all the nodes restored, try testing the cluster. List the members with `etcdctl member list` and try to retrieve
the values of the `newvalue` and `testport` keys:

```
user@ubuntu:~$ etcdctl member list

507ecf5e9ca6b606, started, nodeb, http://172.17.0.3:2380, http://172.17.0.3:2379, false
5c1954e5cd7a3e68, started, nodea, http://172.17.0.2:2380, http://172.17.0.2:2379, false
69b68fd2de47b0f9, started, noded, http://172.17.0.4:2380, http://172.17.0.4:2379, false

user@ubuntu:~$ etcdctl get newvalue

newvalue
11111

user@ubuntu:~$ etcdctl get testport

testport
7777

user@ubuntu:~$
```

Success!

etcdctl allows users to quickly and consistently back up etcd clusters with only a few commands. Unlike the manual
method, the cluster members return exactly as they were running at the time of the snap shot.

<br>

Congratulations you have completed the lab!

<br>


_Copyright (c) 2014-2020 RX-M LLC, Cloud Native Consulting, all rights reserved_

[RX-M LLC]: http://rx-m.io/rxm-cnc.svg "RX-M LLC"
