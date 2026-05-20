export const vpc = new sst.aws.Vpc("KlinkVpc", { bastion: true, nat: "ec2" });
