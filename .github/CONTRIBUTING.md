# Contributing to the Troop 500G Website

Welcome, webmaster! This guide walks you through the full process of making changes to the website — from your first edit to getting it published live.

You never edit the live site directly. Instead, you work on a copy (a **branch**), preview it automatically, and ask an adult webmaster to approve it before it goes live. This keeps the live site safe and gives you a chance to catch mistakes.

---

## The Workflow at a Glance

```
1. Create a branch        →  your own sandbox to work in
2. Open a Draft PR        →  starts the automatic preview build
3. Make your edits        →  every push rebuilds the preview
4. Review the preview     →  verify it looks right at the preview URL
5. Mark PR as Ready       →  requests adult webmaster review
6. Adult approves & merges → changes go live on troop500.org
```

---

## Step-by-Step Instructions

### 1. Create a Branch

In GitHub, go to the **main repository page** and click the branch dropdown (it defaults to `gh-pages`). Type a short descriptive name for your branch and click **Create branch**.

Good branch names describe what you're changing:
- `[your name]/update-grubmaster-page`
- `[your name]/fix-contact-info`
- `[your name]/add-fall-camping-post`

> **Tip:** Keep your branch name lowercase with hyphens, no spaces.

---

### 2. Open a Draft Pull Request

A **Pull Request (PR)** is a request to merge your changes into the live site. Opening it as a **Draft** lets the preview build run while you're still working — no pressure to be done yet.

1. After creating your branch, GitHub will usually show a banner: **"Compare & pull request"** — click it.
2. Fill in the title (what you're changing) and the description fields in the template.
3. At the bottom of the form, click the small arrow next to the green button and choose **"Create draft pull request"**.

> GitHub automatically assigns the adult webmaster as a reviewer (via CODEOWNERS), but they won't be notified to review until you mark the PR as ready.

---

### 3. Make Your Edits

Edit files directly on your branch using GitHub's web editor, or clone the repo and work locally.

Every time you push (save) a change to your branch, the **"Deploy PR Preview"** GitHub Action runs automatically. You can watch its progress in the **Actions** tab or in the **Checks** section at the bottom of your PR.

---

### 4. Check Your Preview

Once the "Deploy PR Preview" action finishes (green ✓), a bot will post a comment in your PR with a link like:

```
https://troop500.org/pr-preview/pr-42/
```

Click the link and browse your changes. Check:
- Does the page look correct?
- Do all links work?
- Does it look okay on a phone? (resize your browser window or use browser DevTools)

If something looks off, fix the file on your branch and push again — the preview will automatically rebuild.

---

### 5. Mark as Ready for Review

When everything looks good:

1. Open your PR on GitHub.
2. Click **"Ready for review"** (the button at the top of the PR, where it says "Draft").
3. The adult webmaster will receive a notification and review your changes.

Use the **self-review checklist** in the PR description to make sure you haven't missed anything.

---

### 6. Adult Webmaster Approves and Merges

The adult webmaster will look over your changes, possibly leave comments or suggestions, and then approve and merge your PR. Once merged, the site automatically rebuilds and your changes are live on **troop500.org** within a few minutes.

---

## Branch Protection (Admin Setup)

> This section is for the adult webmaster who sets up the repository.

To enforce the review workflow, configure branch protection in **GitHub Settings → Branches → Add rule → `gh-pages`**:

| Setting | Value |
|---|---|
| Require a pull request before merging | ✅ Enabled |
| Required approvals | 1 |
| Require review from Code Owners | ✅ Enabled |
| Require status checks to pass | ✅ Enabled — add "deploy-preview" |
| Do not allow bypassing the above settings | ✅ Recommended |

Update `.github/CODEOWNERS` to replace `@adult-webmaster` with your actual GitHub username.

---

## Quick Reference

| Task | Where to do it |
|---|---|
| Create a branch | GitHub repo → branch dropdown → type name |
| Open a draft PR | GitHub repo → "Compare & pull request" → "Create draft pull request" |
| Watch the build | PR page → Checks section, or Actions tab |
| View the preview | Bot comment in your PR with the preview link |
| Mark ready for review | PR page → "Ready for review" button |
| See live site | [troop500.org](https://troop500.org) |
