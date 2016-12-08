#!/usr/bin/env python
import sys, yaml; 

def merge(a, b):
    for key in b:
        if key in a:
            if isinstance(a[key], dict) and isinstance(b[key], dict):
                a[key] = merge(a[key], b[key])
            elif isinstance(a[key], list) and isinstance(b[key], list):
                a[key] = a[key] + b[key]
                if (len(a[key]) > 0 and isinstance(a[key][0], str)) or (len(b[key]) > 0 and isinstance(b[key][0], str)):
                    a[key] = list(set(a[key]))
            #for simple properties with same name just do nothing
        else:
            a[key] = b[key]
    return a

with open(sys.argv[1], 'r') as stream:
    original_manifest = yaml.load(stream)
    all_jobs = {}
    for instance in original_manifest['instance_groups']:
        for job in instance['jobs']:
            if job['name'] in all_jobs:
                all_jobs[job['name']] = merge(all_jobs[job['name']], job)
            else:
                all_jobs[job['name']] = job

    with open(sys.argv[2], 'r') as stream:
        single_vm_manifest = yaml.load(stream)
        
        jobs = []
        for key, val in all_jobs.items():
            jobs.append(val)


        order = {"mysql": 1, "consul_agent": 2, "garden": 3, "etcd": 4, "uaa": 5, "bbs":6}
        def getKey(item):
            if item["name"] in order:
                return order[item["name"]]
            else:
                return 100

        jobs = sorted(jobs, key=getKey)

        single_vm_manifest['instance_groups'][0]['jobs'] = jobs

        original_manifest['instance_groups'] = single_vm_manifest['instance_groups']

        yaml.dump(original_manifest, sys.stdout, indent=2, default_flow_style=False)
