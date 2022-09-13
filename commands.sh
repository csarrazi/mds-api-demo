#!/usr/bin/env bash
CACERT=../../confluent/cp-demo/scripts/security/snakeoil-ca-1.crt
# USERNAME=alice
# PASSWORD=alice-secret

SUPERUSER="superUser"
PASSWORD="superUser"

OBJECT=$1

KAFKA_ENDPOINT=https://localhost:8091
SR_ENDPOINT=https://localhost:8085
CONNECT_ENDPOINT=https://localhost:8083
# C3_ENDPOINT=https://localhost:9022
# RESTPROXY_ENDPOINT=https://localhost:8086
KSQL_ENDPOINT=https://localhost:8089

COMPONENTS=("kafka" "ksql" "connect" "schema-registry")


TOKEN=$(http --verify $CACERT ${KAFKA_ENDPOINT}/security/1.0/authenticate -a $SUPERUSER:$PASSWORD | jq -r .auth_token)

KAFKA_CLUSTER=$(http --verify $CACERT ${KAFKA_ENDPOINT}/v1/metadata/id | jq -r .id)
SR_CLUSTER=$(http --verify $CACERT ${SR_ENDPOINT}/permissions -a $SUPERUSER:$PASSWORD | jq -r '.scope.clusters."schema-registry-cluster"')
CONNECT_CLUSTER=$(http --verify $CACERT ${CONNECT_ENDPOINT}/permissions -a $SUPERUSER:$PASSWORD | jq -r '.scope.clusters."connect-cluster"')
KSQL_CLUSTER=$(http --verify $CACERT ${KSQL_ENDPOINT}/info -a $SUPERUSER:$PASSWORD | jq -r '.KsqlServerInfo.ksqlServiceId')

urlencode () {
    echo $(jq -rn --arg x "$1" '$x|@uri')
}

mds_post () {
    JQ_EXPR="${3:-'.'}"

    RES=$(jq "$JQ_EXPR" $2)

    echo $(jq "$JQ_EXPR" $2 | http --verify $CACERT ${KAFKA_ENDPOINT}$1 "Authorization: Bearer $TOKEN") | jq
}

mds_get () {
    echo $(http --verify $CACERT ${KAFKA_ENDPOINT}$1 "Authorization: Bearer $TOKEN") #  | jq $2)
}

get_bindings () {
    KFK_CLUSTER=${KAFKA_CLUSTER:-$3}
    COMPONENT=${2:-"kafka"}

    JQ='.clusters."kafka-cluster"="'$KAFKA_CLUSTER'"'
    MSG='Getting bindings for "'$OBJECT'" on kafka cluster ID "'$KAFKA_CLUSTER'"'

    case $COMPONENT in
        "schema-registry")
            JQ=''$JQ' | .clusters."schema-registry-cluster"="'$SR_CLUSTER'"'
            MSG=''$MSG' and '$COMPONENT' cluster ID "'$SR_CLUSTER'":'
            ;;
        "ksql")
            JQ=''$JQ' | .clusters."ksql-cluster"="'$KSQL_CLUSTER'"'
            MSG=''$MSG' and '$COMPONENT' cluster ID "'$KSQL_CLUSTER'":'
            ;;
        "connect")
            JQ=''$JQ' | .clusters."connect-cluster"="'$CONNECT_CLUSTER'"'
            MSG=''$MSG' and '$COMPONENT' cluster ID "'$CONNECT_CLUSTER'":'
            ;;
        *)
            MSG=''$MSG':'
            ;;
    esac

    echo "$MSG"

    OBJ=$(urlencode $1)

    # JQ='.clusters."kafka-cluster"="'$KAFKA_CLUSTER'" | .clusters."schema-registry-cluster"="'$SR_CLUSTER'"'
    mds_post /security/1.0/lookup/principal/$OBJ/resources json/scope_clusters_template.json "$JQ"
}

add_bindings () {
    KFK_CLUSTER=${KAFKA_CLUSTER:-$3}
    COMPONENT=${2:-"kafka"}

    JQ='.scope.clusters."kafka-cluster"="'$KAFKA_CLUSTER'"'
    MSG='Getting bindings for "'$OBJECT'" on kafka cluster ID "'$KAFKA_CLUSTER'"'

    case $COMPONENT in
        "schema-registry")
            JQ=''$JQ' | .scope.clusters."schema-registry-cluster"="'$SR_CLUSTER'"'
            MSG=''$MSG' and '$COMPONENT' cluster ID "'$SR_CLUSTER'":'
            ;;
        "ksql")
            JQ=''$JQ' | .scope.clusters."ksql-cluster"="'$KSQL_CLUSTER'"'
            MSG=''$MSG' and '$COMPONENT' cluster ID "'$KSQL_CLUSTER'":'
            ;;
        "connect")
            JQ=''$JQ' | .scope.clusters."connect-cluster"="'$CONNECT_CLUSTER'"'
            MSG=''$MSG' and '$COMPONENT' cluster ID "'$CONNECT_CLUSTER'":'
            ;;
        *)
            MSG=''$MSG':'
            ;;
    esac

    echo "$MSG"

    OBJ=$(jq -rn --arg x "$1" '$x|@uri')

    # JQ='.clusters."kafka-cluster"="'$KAFKA_CLUSTER'" | .clusters."schema-registry-cluster"="'$SR_CLUSTER'"'
    mds_post /security/1.0/lookup/principal/$OBJ/resources json/scope_clusters_template.json "$JQ"
}

echo "Listing bindings for $OBJECT"

for component in ${COMPONENTS[@]}; do
    get_bindings "$OBJECT" "$component"
done

echo "Setting bindings for $OBJECT on Kafka Cluster ID $KAFKA_CLUSTER:"

# http --verify $CACERT $ENDPOINT/security/1.0/registry/clusters "Authorization: Bearer $TOKEN"