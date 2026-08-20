#!/bin/bash

while true; do
    USER_POD_COUNT=$(kubectl get deploy/apdev-user-deploy -n apdev -o jsonpath='{.status.readyReplicas}')
    PRODUCT_POD_COUNT=$(kubectl get deploy/apdev-product-deploy -n apdev -o jsonpath='{.status.readyReplicas}')
    STRESS_POD_COUNT=$(kubectl get deploy/apdev-stress-deploy -n apdev -o jsonpath='{.status.readyReplicas}')

    echo "==="
    echo "User Pod Count: $USER_POD_COUNT"
    echo "Product Pod Count: $PRODUCT_POD_COUNT"
    echo "Stress Pod Count: $STRESS_POD_COUNT"
    echo
    echo "==="
    echo

    sleep 60
done