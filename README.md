# REST Docker

## Get Image

You can get the Docker image or build the Docker image yourself.

### Pull from Docker Hub

The URL is [Docker Hub - bsplu/rest_docker](https://hub.docker.com/r/bsplu/rest_docker).

To pull the image from Docker Hub, follow these steps:

1. Open your terminal.
2. Run the following command to pull the image:
    ```sh
    docker pull bsplu/rest_docker
    ```
3. To verify that the image has been pulled, run:
    ```sh
    docker images
    ```
    This command will list all the Docker images on your system.

### Build Docker Image Yourself

To build the Docker image yourself, follow these steps:

1. Open your terminal.
2. Navigate to the directory containing the Dockerfile.
3. Run the following command to build the image:
    ```sh
    docker build -t rest/[environment_specific]:v[version] . -f Dockerfile
    ```
    This command will create a Docker image with the tag `rest/[environment_specific]:v[version]`.

## Run

### Shell Mode (for debugging)

To run the container in interactive mode (useful for debugging), follow these steps:

1. Open your terminal.
2. Run the following command:
    ```sh
    docker run --rm -it rest/[environment_specific]:v[version] /bin/bash
    ```
3. Inside the container, you can run your commands as needed.
4. When you are done, type `exit` to leave the container. The container will be cleaned up automatically.

### Exec Mode (for job submission)

To run the container for job submission, follow these steps:

1. Open your terminal.
2. Mount a local directory to the container and set the working directory by running:
    ```sh
    docker run --rm -v /path/to/local/dir:/path/in/container -w /path/in/container rest/[environment_specific]:v[version] /bin/bash -c "rest"
    ```
    Replace `/path/to/local/dir` with the path to your local directory and `/path/in/container` with the desired path inside the container.
3. The command `rest` will be executed inside the container with the specified working directory.
4. When the job is done, the container will exit and be cleaned up automatically.

## Convert to Singularity

To convert the Docker image to a Singularity image, follow one of the two methods below:

### Option 1: Using docker-daemon

Run the following command:
```sh
singularity build rest_[environment_specific]_v[version].sif docker-daemon://rest/[environment_specific]:v[version]
```

### Option 2: Export Docker Image to a TAR file

1. Export the Docker image to a TAR file:
    ```sh
    docker save -o rest_[environment_specific]_v[version].tar rest/[environment_specific]:v[version]
    ```
2. Build the Singularity image from the TAR file:
    ```sh
    singularity build rest_[environment_specific]_v[version].sif docker-archive://rest_[environment_specific]_v[version].tar
    ```

### Run the Singularity Container

Once the Singularity image is built, you can run it with:
```sh
singularity exec --bind /path/to/local:/path/in/container rest_[environment_specific]_v[version].sif bash -c "rest"
```