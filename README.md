# REST Docker

## Getting the Docker Image

You can either pull the Docker image from Docker Hub or build it yourself.

### Pull from Docker Hub

To pull the image from Docker Hub, follow these steps:

1. Open your terminal.
2. Run the following command:
    ```sh
    docker pull bsplu/rest_docker
    ```
3. Verify the image has been pulled by running:
    ```sh
    docker images
    ```

### Build the Docker Image

To build the Docker image yourself, follow these steps:

1. Open your terminal.
2. Navigate to the directory containing the Dockerfile.
3. Run the following command:
    ```sh
    docker build -t [name]:[version] .
    ```
4. Verify the images after a successful build:
    ```sh
    docker images
    ```
5. [Optional] After you build, you may want to clean the cache:
    ```sh
    docker image prune -f
    ```

**Note:**
- `[name]` is the image name you want to use, like `rest/mpi`, `your_name/rest/x86`, etc.
- `[version]` is the version tag for the named image, like `v0.2`, etc.
- If you are in China, you may want to use `docker build --build-arg CHINA=True -t [name]:[version] .` to speed up downloading files.

## Running the Docker Container

### Shell Mode (for Debugging)

To run the container in interactive mode:

1. Open your terminal.
2. Run the following command:
    ```sh
    docker run --rm -it [name]:[version] /bin/bash
    ```
3. When done, type `exit` to leave the container.

### Exec Mode (for Job Submission)

To run the container for job submission:

1. Open your terminal.
2. Run the following command:
    ```sh
    docker run --rm -v /path/to/local/dir:/path/in/container -w /path/in/container [name]:[version] /bin/bash -c "rest"
    ```

## Converting to Singularity

### Using docker-daemon

Run the following command:
```sh
singularity build [name]_[version].sif docker-daemon://[name]:[version]
```

### Export Docker Image to a TAR File

1. Export the Docker image:
    ```sh
    docker save -o [name]_[version].tar [name]:[version]
    ```
2. Build the Singularity image:
    ```sh
    singularity build [name]_[version].sif docker-archive://[name]_[version].tar
    ```

### Running the Singularity Container

To run the Singularity container:
```sh
singularity exec --bind /path/to/local:/path/in/container [name]_[version].sif bash -c "rest"
```

## For Developers

- If you want to debug code in the image, you can run:
    ```sh
    docker run --rm -it [name]:[version] sudo su - && /bin/bash
    ```
- If you want to write a Dockerfile based on this repository, you can use:
    ```dockerfile
    FROM bsplu/rest_docker
    USER root
    ```
