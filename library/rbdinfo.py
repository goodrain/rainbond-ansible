#!/usr/bin/python
# -*- coding: utf-8 -*-

from ansible.module_utils.basic import *

EXAMPLES = '''
- rbdinfo:
    info: 'next step download image.tgz'
'''

def main():
    module = AnsibleModule(
        argument_spec = dict(
            info=dict(type='str', default='The next task may take some time to execute'),
        ),
        supports_check_mode=True
    )

    infodata = dict(stdout=module.params['info'],changed=False,rc=0,msg=module.params['info'])
    module.exit_json(**infodata)

if __name__ == '__main__':
    main()