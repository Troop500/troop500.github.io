The website of Scouting America Troop 500G

## Building with GitHub Actions
TODO: Update.  GitHub will automatically build and deploy the site based on commits to gh-pages branch. 

## Building Locally with Docker

### Dependencies

Ensure you have Docker installed on your system. You can follow the instructions for your operating system:

- **Windows**: [Install Docker Desktop on Windows](https://docs.docker.com/desktop/install/windows-install/)
- **Ubuntu**: [Install Docker Engine on Ubuntu](https://docs.docker.com/engine/install/ubuntu/)
- **Mac**: [Install Docker Desktop on Mac](https://docs.docker.com/desktop/install/mac-install/)

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

### Build the Jekyll site
```sh
docker run --rm --volume="$PWD:/srv/jekyll" -it jekyll/jekyll:$JEKYLL_VERSION jekyll build
```

### Serve the Jekyll site
```sh
docker run --name newblog --volume="$PWD:/srv/jekyll" -p 4000:4000 -it jekyll/jekyll:$JEKYLL_VERSION jekyll serve --watch --drafts
```