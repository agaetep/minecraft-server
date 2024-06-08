CS 312 Course Project Part 2

# Dependencies

Terraform
Ansible

# Credentials

Though this is a fully automated solution, AWS credentials are needed to create the instance. So, the only setup you will need to do is provide your AWS secret key, access key, and session token into the `aws_credentials` file.

# Executable Permissions

Make sure the setup script has executable permissions:

```
$ chmod +x ./setup.sh
```

