The website of Scouting America Troop 500G

## Building with GitHub Actions
TODO: Update.  GitHub will automatically build and deploy the site based on commits to gh-pages branch. 

## Building Locally with Docker

### Dependencies

Ensure you have Docker installed on your system. You can follow the instructions for your operating system:

- **Windows**: [Install Docker Desktop on Windows](https://docs.docker.com/desktop/install/windows-install/)
- **Ubuntu**: [Install Docker Engine on Ubuntu](https://docs.docker.com/engine/install/ubuntu/)
- **Mac**: [Install Docker Desktop on Mac](https://docs.docker.com/desktop/install/mac-install/)

### Cloning the Repository

To clone the repository, run the following command:

```sh
git clone https://github.com/troop500/troop500.github.io.git
```

### Navigate to the Project Directory

After cloning the repository, navigate to the project directory:

```sh
cd troop500.github.io 
```

### Build the Jekyll site
```sh
docker run --rm --volume="$PWD:/srv/jekyll" -it jekyll/jekyll:latest jekyll build
```

### Serve the Jekyll site

To serve the site locally, you can use Docker. The Docker container temporarily runs, serving the site locally until it is stopped. This allows you to test the site in a local environment that mimics the production environment.

To serve the site using Docker, run the following command:

```sh
docker run --rm --name troop500 --volume="$PWD:/srv/jekyll" -p 4000:4000 -it jekyll/jekyll:latest jekyll serve --watch --drafts
```

This command does the following:
- `docker run --rm --name troop500`: Runs a new Docker container with the name `troop500` and removes the container when it exits.
- `--volume="$PWD:/srv/jekyll"`: Mounts the current directory (`$PWD`) to `/srv/jekyll` in the container, so the container has access to your site's files.
- `-p 4000:4000`: Maps port 4000 on your host to port 4000 in the container, allowing you to access the site at `http://localhost:4000`. Change this command if port 4000 is used elsewhere.
- `-it`: Runs the container in interactive mode with a TTY.
- `jekyll/jekyll:latest`: Uses the (latest) official Jekyll Docker image.
- `jekyll serve --watch --drafts`: Runs the `jekyll serve` command inside the container to build and serve the site, watching for changes and including drafts.

The site will be available at `http://localhost:4000` until you stop the Docker container.

## Adding and Removing Posts

### Adding a Post

1. Navigate to the `_posts` directory.
2. Create a new file with the naming convention `YYYY-MM-DD-title.md`.
3. Add the following front matter to the top of the file:
    ```markdown
    ---
    layout: post
    title: "Your Post Title"
    author: "Your Name"
    date: YYYY-MM-DD HH:MM:SS -0500
    categories: category1 category2
    ---
    ```
4. Write your post content below the front matter.
5. Save the file and commit your changes.

### Removing a Post

1. Navigate to the `_posts` directory.
2. Locate the file you want to remove.
3. Delete the file.
4. Commit your changes.

## Adding a New Page

To add a new page to the site:

1. Navigate to the `pages` directory of the project.
2. Create a new file with a descriptive name (e.g., `files.md` for a Files page).
3. Add the following front matter to the top of the file:
    ```markdown
    ---
    layout: page
    title: "Page Title"
    permalink: /page-permalink
    ---
    ```
    Replace `Page Title` with the title of the page and `page-permalink` with the desired URL path for the page.
4. Add the content for the page below the front matter. For example, the Files page includes:
    ```markdown
    Welcome to the Documents page. Here you can find important files and resources for Troop 500G.

    - [Inventory - Patrol Box](assets/files/inventory-patrol-box.pdf){:target="_blank"}
    ```
5. Open the `_data/settings.yml` file and add the new page to the `menu` section. Use the following format:
    ```yaml
    - {name: 'Page Title', url: 'page-permalink'}
    ```
    Replace `Page Title` with the title of the page and `page-permalink` with the permalink defined in the front matter.
6. Save your changes and commit them to the repository.

## Adding a New File

To add a new file to the site:

1. Place the file in the `assets/files/` directory. Ensure the file name is descriptive and uses lowercase letters with hyphens as separators (e.g., `inventory-troop-gear.pdf`).
2. Open the `pages/files.md` file.
3. Add a new list item with a link to the file. Use the following format:
    ```markdown
    - [File Description](assets/files/filename.pdf){:target="_blank"}
    ```
    Replace `File Description` with a meaningful description of the file and `filename.pdf` with the actual file name.
4. Save your changes and commit them to the repository.