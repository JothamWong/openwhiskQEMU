# openWhisk QEMU

This repository contains instructions on setting up the following two components

1. OpenWhisk
2. Serverless Benchmarks suite

on an x86 virtual machine using QEMU.

Your computer should have KVM.

## Building the disk image from scratch

This section is for reproducing the disk image from scratch. (Tested and reproduced on ubuntu 20.04, no other versions have been tested)

First, run booga.sh.

`booga.sh` will download the 20.04 cloud image, create a 256G disk alongside the cloudinit and set up the VM with credentials

```
username: ubuntu
password: ubuntu
```

Change -smp to the number of cores you wish to use. Adjust other parameters as necessary.
Now, you are inside the VM (if you exit, run `bash run.sh` to enter again)
You can also SSH into the QEMU VM with `ssh ubuntu@127.0.0.1 -p 2222`

I personally prefer SSHing into the QEMU VM and afking on the main qemu command cos it doesnt run into
the terminal line overwrap issue which is kinda annoying.

Next, clone the relevant repositories

```bash
git clone https://github.com/JothamWong/openwhisk.git
git clone https://github.com/JothamWong/serverless-benchmarks.git
```

My forked repo of openwhisk has had the default modifications baked in for a painless deployment (read: no need to manually modify the scala files) and so on.

Download all necessary dependencies

```bash
sudo apt update
sudo apt install python3.8-venv ansible tar
```

A quick sanity check on ansible, cos it has been a source of issues in the past.
```bash 
$ ansible --version
ansible [core 2.12.10]
  config file = /home/ubuntu/openwhisk/ansible/ansible.cfg
  configured module search path = ['/home/ubuntu/.ansible/plugins/modules', '/usr/share/ansible/plugins/modules']
  ansible python module location = /usr/lib/python3/dist-packages/ansible
  ansible collection location = /home/ubuntu/.ansible/collections:/usr/share/ansible/collections
  executable location = /usr/bin/ansible
  python version = 3.8.10 (default, Mar 25 2024, 10:42:49) [GCC 9.4.0]
  jinja version = 2.10.1
  libyaml = True
```

In one shell, build openwhisk, this will take awhile

```bash
cd openwhisk
# On my 48 core cpu, takes about 10-21 minutes. YMMV
./gradlew distDocker
# Feel free to clear the .gradle file/cache afterwards, we won't be needing them anymore
# After this is done, we will deploy the local deployment of Openwhisk using ansible
cd ansible
# Running setup.yml first is CRUCIAL becos otherwise the other inventories wont be set up
# and you will get parsing errors.
ansible-playbook -i environments/local setup.yml
ansible-playbook -i environments/local prereq.yml
ansible-playbook -i environments/local couchdb.yml
ansible-playbook -i environments/local initdb.yml
ansible-playbook -i environments/local wipe.yml
ansible-playbook -i environments/local elasticsearch.yml
# A bulk of the time will be from pulling the openwhisk action runtime docker images
# it's completely normal if you see that the warmup failed, this fails on the official
# openwhisk automated tests too. In fact, I wud be shocked if it passed!
# It's also fine for the wsk cli set up to fail, we will be doing it manually
ansible-playbook -i environments/local  -e limit_invocations_per_minute=999999 -e limit_invocations_concurrent=999999 -e db_activation_backend=ElasticSearch openwhisk.yml

# TODO: Figure out if this is actually necessary, likely not
# installs a catalog of public packages and actions
ansible-playbook -i environments/local postdeploy.yml
# to use the API gateway
ansible-playbook -i environments/local apigateway.yml
ansible-playbook -i environments/local routemgmt.yml
```

Setting up the wsk cli. These values are p much hardcoded for all deployments of 
openwhisk but cud always be changed.
```bash
wget https://github.com/apache/openwhisk-cli/releases/download/1.2.0/OpenWhisk_CLI-1.2.0-linux-amd64.tgz
tar -xvf OpenWhisk_CLI-1.2.0-linux-amd64.tgz
sudo mv wsk /usr/bin/wsk
rm ~/.wskprops
echo "APIHOST=172.17.0.1
AUTH=23bc46b1-71f6-4ed5-8c54-816aa4f8c502:123zO3xZCLrMN6v2BKK1dXYFpXlPkccOFqm12CdAsMgRU4VrNZ9lyGVCGuMDGIwP" > ~/.wskprops
```

At this point, take a snapshot so we don't have to do all this again!

Test that the wsk cli has been properly set up by invoking a built in action

```bash
qemu-img snapshot -c openwhisk_setup openwhisk-vm.qcow2
# Verify that the snapshot exists
qemu-img snapshot -l openwhisk-vm.qcow2
# Snapshot list:
# ID        TAG               VM SIZE                DATE     VM CLOCK     ICOUNT
# 1         openwhisk_setup       0 B 2024-07-22 16:02:42 00:00:00.000          0
```

Now we can revert to this snapshot anytime we mess up, or simply just becos

```bash
qemu-img snapshot -a checkpoint_name openwhisk-vm.qcow2
```

Now we will set up the serverless benchmark.

```bash
cd serverless-benchmarks
python3 install.py
# Now wait for Openwhisk to be fully deployed in the other terminal, then proceed
. python-venv/bin/activate
# Now you are in the python venv for sebs and can run benchmarks!
```

### Crucial notes

Ansible

Need to run `setup.yml` first or you will get cannot parse file as inventory source errors.
The majority of the time is spent on pulling the action runtimes, which are kinda large.
