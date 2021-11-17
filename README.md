# s3-automate
## Install awscli on your linux machine 
`yum install awscli -y`
## configure with your aws credentials
`aws configure`
## download the script file and give execute permissions
`chmod +x script`
## features
- get total bucket size(current and non current versions)
- get size based each storage classes(only STANDARD STANDARD IA GLACIER)
- cost estimation based on size on above storage classes
- print size based current and above period of time
- print number of objects(current and non current versions)
## run script
`./script <bucketname>`

sample output:
![Screenshot 2021-11-15 at 12 22 38 PM](https://user-images.githubusercontent.com/18322161/141967964-8f1344f6-4af1-4f26-b8be-7f12fdfacc12.png)
