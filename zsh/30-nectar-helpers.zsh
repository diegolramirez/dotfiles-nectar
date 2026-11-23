# 30-nectar-helpers.zsh — ThinkNectar AWS & Teleport helpers

# Add keg-only Homebrew libpq binaries when installed
if [[ -d "/opt/homebrew/opt/libpq/bin" ]]; then
  typeset -U path PATH
  path=("/opt/homebrew/opt/libpq/bin" $path)
  export PATH
fi

# Disable autocorrection for Teleport CLI
alias tsh='nocorrect tsh'

# Switch AWS profiles (defaults to mfa)
aws_profile() {
    local PROFILE=${1:-mfa}
    export AWS_PROFILE="$PROFILE"
    echo "Switched to AWS Profile: $AWS_PROFILE"

    if [[ "$PROFILE" == "mfa" ]]; then
        local IDENTITY_OUT
        IDENTITY_OUT=$(aws sts get-caller-identity --query "Arn" --output text 2>&1)
        local EXIT_CODE=$?

        if [[ $EXIT_CODE -eq 0 ]]; then
            echo "Identity: $IDENTITY_OUT"
            if [[ -f "$HOME/.aws/.mfa_expiration" ]]; then
                echo "Session expires: $(cat "$HOME/.aws/.mfa_expiration")"
            fi
        else
            echo "AWS Session Error: $IDENTITY_OUT"
        fi
    fi
}

# Export active AWS credentials into current shell environment
alias aws-export='eval $(aws configure export-credentials --format env) && echo "AWS credentials exported (expires: $AWS_CREDENTIAL_EXPIRATION)"'

# Teleport SSH aliases
alias tsh-pipes-prod='tsh ssh ec2-user@pipes-prod'
alias tsh-pipes-dev='tsh ssh ec2-user@pipes-dev'
alias tsh-pipes-demo='tsh ssh ec2-user@pipes-demo'
alias tsh-batch-service='tsh ssh ubuntu@batch-service'
alias tsh-pulse='tsh ssh ubuntu@pulse'
alias tsh-airflow='tsh ssh ubuntu@airflow'
