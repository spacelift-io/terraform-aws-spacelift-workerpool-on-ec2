# Custom IAM Role

In this example, we are using a custom IAM role instead of having the module create one for us.

Please make sure that the custom IAM role can be assumed by AWS EC2 and that it has the following managed policies attached:

- `arn:aws:iam::aws:policy/AutoScalingReadOnlyAccess`
- `arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy`
- `arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore`
