$loadBalancers = aws elbv2 describe-load-balancers --query 'LoadBalancers[*].{Name:LoadBalancerName,Arn:LoadBalancerArn}' --output json | ConvertFrom-Json

Write-Host "Checking Application/Network Load Balancers (ALBs/NLBs)..."

foreach ($lb in $loadBalancers) {
    $lbName = $lb.Name
    $lbArn = $lb.Arn

    Write-Host "Checking Load Balancer: $lbName ($lbArn)"
    
    $targetGroups = aws elbv2 describe-target-groups --load-balancer-arn $lbArn --query 'TargetGroups[*].TargetGroupArn' --output json | ConvertFrom-Json

    if (-not $targetGroups) {
        Write-Host "No target groups found for Load Balancer: $lbName"
        continue
    }

    $empty = $true
    foreach ($tgArn in $targetGroups) {
        $targets = aws elbv2 describe-target-health --target-group-arn $tgArn --query 'TargetHealthDescriptions[*].Target.Id' --output json | ConvertFrom-Json
        
        if ($targets.Count -gt 0) {
            $empty = $false
            Write-Host "Target group $tgArn has registered targets."
        }
    }

    if ($empty) {
        Write-Host "Load Balancer: $lbName has no registered targets in any target group."
    }
}
