## SST Config

To configure SST to use the [right iam user](https://us-east-1.console.aws.amazon.com/iam/home?region=eu-north-1#/users/details/sst-klink?section=security_credentials). You can either add the user to the config.

```toml
# ~/.aws/credentials
[free-klink-sst]
aws_access_key_id = XXX
aws_secret_access_key = YYY
```

or you can set the env variables for example with `export NAME`

```
AWS_ACCESS_KEY_ID = XXX
AWS_SECRET_ACCESS_KEY = YYY
```

reference: [SST - IAM Credentials](https://sst.dev/docs/iam-credentials/#precedence)

## Structure

The structure of this project is a monorepo with the addition of using sst the manage the infrastructure.
**Overview:**

```
- infra # this folder hold all the components that make up the infrastructure
- packages # packages of the monorep managed by the bun workspace as a monorepo
- sst.config.ts # main place to setup sst - e.g. import components from the infra folder so they are actually deployed
```
