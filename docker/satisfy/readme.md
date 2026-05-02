# Satisfy

## Usage

To start the container, run the following command:
`docker compose -p q1knet -f compose.server.yaml up -d`

To access the container, run the following command:

`docker compose -p q1knet -f compose.server.yaml exec satisfy bash`

and then you can run the following command to build satis:

`./bin/satis build`
