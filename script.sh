####################################################
#
#
#   Script to provision private gke
#
#   preRequisite: kubectl, gcloud, terraform, helm
#
#  
#
####################################################
_parse_args() {
    if [ $# != 0 ]; then
        while true ; do
        case "$1" in
            --trusted-ip)
                TRUSTED_IP=$2
                shift 2
            ;;
            --project)
                PROJECT=$2
                shift 2
            ;;
            --action)
                ACTION=$2
                shift 2
            ;;
            --environment)
                ENVIRONMENT=$2
                shift 2
            ;;
            --help)
                help
                shift
            ;;
            *)
                break
            ;;
        esac
        done
    fi
}

function help {
    echo "./script.sh --action [apply|destroy|plan] --trusted-ip [<ip/32>] --project [project id/name] --environment [production|staging]"
    exit 1
}
function main {
    _parse_args $@

    PWD=$(pwd)

    echo "provisioning GKE private cluster"

    cd terraform
    echo > vars.tfvars
    echo "trusted_ip = \"$TRUSTED_IP\"" >> vars.tfvars

    echo "region = \"us-east1\"" >> vars.tfvars
    echo "cluster_name = \"rlt\"" >> vars.tfvars
    echo "min_nodes = \"1\"" >> vars.tfvars
    echo "max_nodes = \"2\"" >> vars.tfvars
    echo "auto_upgrade = \"false\"" >> vars.tfvars
    echo "machine_type = \"n1-standard-2\"" >> vars.tfvars
    echo "project = \"$PROJECT\"" >> vars.tfvars
    terraform workspace new $ENVIRONMENT
    if [[ $ACTION == "apply" ]]; then
        if [[ -z $TRUSTED_IP ]]; then
            echo "Trusted ip is required"
            exit 1
        fi
        terraform init
        terraform workspace select $ENVIRONMENT 
        terraform apply -var-file=vars.tfvars --auto-approve
        ## Calling other functions
            gcr
            update_gcr_keys
            ingress_controller
            external_dns
            deploy_app
            deploy_istio
        ## Done
    elif [[ $ACTION == "destroy" ]]; then
        terraform init
        terraform workspace select $ENVIRONMENT
        terraform destroy -var-file=vars.tfvars --auto-approve
    elif [[ $ACTION == "plan" ]]; then
        terraform init
        terraform workspace select $ENVIRONMENT
        terraform plan -var-file=vars.tfvars
    fi

    if [[ $? == 0 ]]; then

        gcloud container clusters get-credentials rlt --region us-east1 --project $PROJECT

    else
        echo "Cluster creation failed ?"
    fi

    $PWD
}

function gcr {
    _parse_args $@
    
    docker build -t gcr.io/$PROJECT/rlt-test:latest -f application/Dockerfile .
    gcloud docker -- push gcr.io/$PROJECT/rlt-test:latest
    
    $PWD
}

function update_gcr_keys {

    kubectl create secret docker-registry gcr-json-key --docker-server=gcr.io --docker-username=_json_key --docker-password="$(cat ./gcr_sa.json)" --docker-email=demo@email.id


    kubectl patch serviceaccount default -p '{"imagePullSecrets": [{"name": "gcr-json-key"}]}'

}

function ingress_controller {
    helm install nginx-ingress --namespace kube-system stable/nginx-ingress
}

function external_dns {
    kubectl create secret generic google-service-account --from-file=./gcr_sa.json --namespace kube-system

    helm install external-dns --namespace kube-system bitnami/external-dns --set "provider=google"  --set "google.project=flow-on-k8s-test" --set "google.serviceAccountSecret=google-service-account"

}

function deploy_app {
    _parse_args $@
    sed -i 's/REPOSITORY/gcr.io\/'"$PROJECT"'\/rlt-test\/g' ./chart/values.yaml

    helm install rtl-test --namespace default ./chart
}

function deploy_istio {

    curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.7.1 sh -

    cd istio-1.7.1 && export PATH=$PWD/bin:$PATH

    istioctl install --set profile=demo

    kubectl label namespace default istio-injection=enabled

}

main "$@"
