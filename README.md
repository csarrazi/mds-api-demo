# Demo CLI to access Confluent's MDS API

## Requirements
To make these examples work, you need:
* jq
* httpie
* cp-demo

## Configuration
Adjust the path to cp-demo's certificate authority folder

## Usage

./commands.sh <OBJECT>

<OBJECT>: The target from which you want to get the role binding

E.g.: User:connectorSA
E.g.: User:connectorSubmitter
Etc.

