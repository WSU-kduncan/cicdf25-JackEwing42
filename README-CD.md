# Part 1
## EC2 Instance
`AMI id:` al2023-ami-2023.9.20251117.1-kernel-6.1-x86_64<br>
`Instance type:` t2.micro<br>
`Recommended volume size:` 30 GB<br>
`Security Group Configuration:` port 22 for ip ranges 132.108.0.0/16 and 76.190.0.0/16 (For WSU and Home respectively), and port 9000 for the ip range 192.30.252.0/22 (Github's current hook ip range. This is preferablly better than dockerhub which has no static ip address for webhook, which means I would need to set the ip range as 0.0.0.0/0 allowing all ip addresses access through port 9000).<br>
## Docker Setup
Docker can be installed on an EC2 instance using the command `sudo yum install -y docker`<br>
### Additional Dependencies<br>
- 64-bit kernal and CPU with virtualization support
- Linux kernal version 3.10 or later
- The `systemd` init system<br>
`Ubuntu:` Requires using the command `sudo apt-get install apt-transport-https ca-certificates curl software-properties-common -y` to allow packages to download over HTTPS.<br>
`Red Hat:` Requires using the command `sudo dnf install -y yum-utils device-mapper-persistent-data lvm2` which assist with managing repository settings and storage drivers.<br>
You can test that docker is running by running the `hello-world` image (a good base image that tests docker) or by checking with the command `sudo systemctl status docker`<br>
## Testing on EC2 Instance
The user can pull an image from docker hub using the following command: `docker pull <username>/<repo-name>:<tag>`. Replacing with the users own information.<br>
The user can create a container using that image with the command: `docker run -XX --name <container_name> -p <instance port>:<container port> <image_name>:<tag>`. Replacing with the users own information.<br>
- It is noteworthy with the `-XX` that this can have two options.
  - `-d` This makes the container a "Detached Container". This container runs in the background, has no direct input while the output goes to Docker logs, is for long-running services like databases and APIs, and will keep running after exiting unless explicitly stopped.
  - `-it` This makes the container a "Interactive Container". This container runs in the foreground, allow for user input while the user is shown direct output, is for running temporary things like shell sessions and debugging, and will stop after it has been exited.<br>
The user can test that the web server is running with the command `docker ps` or with the command `curl http://localhost:<instance port>`<br>
## Scripting Container Application Refresh
#### Bash Script Description
The bash script will first remove the most rescent container that ran, pull the latest tagged image from dockerhub, and create a container off that image. Next it will create the variables necessary for the next part. The last part has the script entering the local repo directory, creating the deployment folder (if it is not created already), copy the script into the repo, stage a commit, commit the changes, and push the changes. If/Else statements are made throughout the steps to check if the action was accomplished, if not, the script stops and echos a reason<br>
As stated in the previous answer, the script has If/Else statements that will tell the user if the previous step was accomplished with an echo. The script ends with a final check that echos "Process complete"<br>
[Bash Script](deployment/cd-bashscript)<br>
# Part 2
## Configuring a webhook listener
To download adnanh's webhook the user needs to use the command `sudo wget https://github.com/adnanh/webhook/releases/download/2.8.0/webhook-linux-amd64.tar.gz` in a directory dedicated to webhooks. After that the user should create a tar file of the executable and then change the permissions to allow executions. Thr user should then create a `hooks.json` file and a corresponding `deploy.sh` file for executing webhooks.<br>
The user can test that webhooks is up and running with the command `sudo ./webhook-linux-amd64/webhook -hooks hooks.json -verbose`, this command will show the user that webhooks is listening on port 9000 and will also report the ip addresses it hears.<br>
The definition file `hooks.json` is a basic configuration file with only one added feature, the trigger rule is put in as a security measure, so that the file is only executed when the conditions are met.<br>
To verify `hooks.json` has loaded correctly we need to use the command `sudo ./webhook-linux-amd64/webhook -hooks hooks.json -verbose` and look for a line like `[webhook] 2025/12/31 23:59:59 [redeploy-webhook] is serving hook requests at /hooks/redeploy-webhoo`. This line tells us that the hook file is running properly in a directory created by the server that is used to listen for triggers.<br>
To verify that webhook is receiving payloads that trigger it we need to go back to our old friend `sudo ./webhook-linux-amd64/webhook -hooks hooks.json -verbose` and look through the verbose again, this time keep it running as you send a payload from your machine using curl or a trigger form github. The logs will output lines that say: 
- `incoming HTTP request received, IP: ...`
- `redeploy-webhook hook triggered successfully`
- `Executinh command: /var/www/webhooks/deploy.sh`
- `Command output: ...`
- `Finished executing command`<br>
These lines will confirm that the payload has been sent successfully and that webhook heard it. You can also look at the command `docker ps`, running this command after a payload is sent will show that the container briefly closed and then reopened.<br>
[Hook/Definition file](deployment/hooks.json)<br>
## Configure a webhook service
The service file in question is a basic webhook service file with some slight modifications, namely the ordering dependency has been changed to `After=network-online.target` with the additional `Wants=network-online.target` added so that `network-online.target` will actually start. The second addition is the `Type=simple` line added under `[Service]`, this line will allow for a faster boot, direct supervision of `systemd`, and this command will take note of the logs in `journalctl`.<br>
To enable and start the webhook, the following commands need to be run:<br>
- `sudo systemctl daemon-reload`: This will reload the configuration of `systemd`
- `sudo systemctl start webhook`: This will start webhook
- `sudo systemctl enable webhook`: This will enable webhook every tiem the EC2 instance is started or rebooted<br>
For verifying that webhook service is capturing payloads and triggering the bash script the user needs to use the command `sudo journalctl -u webhook -f` and look for the same output shown above:
- `incoming HTTP request received, IP: ...`
- `redeploy-webhook hook triggered successfully`
- `Executinh command: /var/www/webhooks/deploy.sh`
- `Command output: ...`
- `Finished executing command`<br>
[Service File](deployment/webhook.service)<br>
# Part 3
## Configuring a Payload Sender
For this project I chose Github as a payload sender. My main reason for doing this was github uses a static ip address for webhook, where dockerhub does not. This allows for a tighter security group and negates the use of a `0.0.0.0/0` ip range.<br>
To enable github for webhook the user needs to go to `Their Repo`>`Settings`>`Webhooks` and click Add webhook. The user needs to then fill out the necessary fields.<br>
Right now github has the webhook set to trigger when a push occurs.<br>
In the webhook tab on github there should be a green checkmark icon next to the webhook you just created.<br>
There are two things you can do to validate that the webhook only triggers when requests are coming from the apporopriate source. First is by properly setting up the scurity group to only allow github or dockerhub inbound traffic on port 9000. The second is what I showed for my definition, that is to write a trigger rule into the definition file.<br>
# Part 4
## Overview
The purpose of this assignment was to familiarize ourselves with these tools given and with continuous deployment. The tools used and their roles are AWS for hosting adnanhs webhook which set up a pipeline to Github for continuous deployment.<br>
[CD Project Diagram.pdf](https://github.com/user-attachments/files/24046218/CD.Project.Diagram.pdf)<br>
## Resources
[adnanh's webhook](https://github.com/adnanh/webhook)<br>
[systemd System and Service Manager](https://systemd.io/)<br>
[Red HAt Documentation](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/9/html/using_systemd_unit_files_to_customize_and_optimize_your_system/assembly_working-with-systemd-unit-files_working-with-systemd)<br>
[Using GitHub actions and webhooks](https://levelup.gitconnected.com/automated-deployment-using-docker-github-actions-and-webhooks-54018fc12e32)
