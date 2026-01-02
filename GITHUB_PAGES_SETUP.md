# GitHub Pages Setup Guide

Complete guide to deploy your React Native Auth Client documentation to GitHub Pages.

## What Has Been Set Up

Your repository now includes a complete Jekyll-based documentation site with:

### ✅ Created Files and Directories

```
react-native-auth-client/
├── .github/
│   └── workflows/
│       └── pages.yml                  # GitHub Actions deployment workflow
├── docs/
│   ├── _layouts/
│   │   └── default.html              # Custom layout with navigation
│   ├── assets/
│   │   └── css/
│   │       └── style.scss            # Custom styling
│   ├── _config.yml                   # Jekyll configuration
│   ├── Gemfile                       # Ruby dependencies
│   ├── index.md                      # Home page
│   ├── documentation.md              # Complete documentation
│   ├── api-reference.md              # API reference
│   └── examples.md                   # Code examples
└── GITHUB_PAGES_SETUP.md             # This file
```

### ✅ Features Included

- **Jekyll Static Site Generator**: Professional documentation site
- **Cayman Theme**: Clean, modern GitHub-style theme
- **Custom Styling**: Enhanced CSS with improved code blocks, tables, and navigation
- **Automatic Deployment**: GitHub Actions workflow for automatic deployment
- **SEO Optimization**: Jekyll SEO plugin with meta tags
- **Sitemap & RSS Feed**: Automatic generation for search engines
- **Responsive Design**: Mobile-friendly layout
- **Navigation Menu**: Easy access to all documentation sections

---

## Step-by-Step Setup Instructions

### Step 1: Commit and Push the Changes

First, commit all the new documentation files to your repository:

```bash
# Stage all new files
git add .github/workflows/pages.yml
git add docs/
git add GITHUB_PAGES_SETUP.md

# Commit
git commit -m "docs: Set up GitHub Pages with Jekyll documentation site"

# Push to GitHub
git push origin main
```

### Step 2: Enable GitHub Pages

1. **Go to your repository on GitHub**
   - Navigate to: https://github.com/rahulunni73/react-native-auth-client

2. **Open Settings**
   - Click on the "Settings" tab in your repository

3. **Navigate to Pages**
   - In the left sidebar, click on "Pages" under "Code and automation"

4. **Configure Source**
   - Under "Build and deployment"
   - Source: Select **"GitHub Actions"**
   - (This allows the workflow to deploy instead of using the default Jekyll build)

5. **Save**
   - The settings should save automatically

### Step 3: Trigger the First Deployment

The GitHub Actions workflow will trigger automatically when you push to the `main` branch. However, you can also trigger it manually:

1. **Go to the Actions tab** in your repository
2. **Click on "Deploy Jekyll site to GitHub Pages"** workflow
3. **Click "Run workflow"** button
4. **Select the `main` branch** and click "Run workflow"

### Step 4: Wait for Deployment

1. **Monitor the deployment** in the Actions tab
2. The workflow has two jobs:
   - **Build**: Builds the Jekyll site (~2-3 minutes)
   - **Deploy**: Deploys to GitHub Pages (~1 minute)
3. Once complete, you'll see green checkmarks ✅

### Step 5: Access Your Documentation Site

Your documentation will be available at:

**https://rahulunni73.github.io/react-native-auth-client/**

Pages available:
- Home: https://rahulunni73.github.io/react-native-auth-client/
- Documentation: https://rahulunni73.github.io/react-native-auth-client/documentation
- API Reference: https://rahulunni73.github.io/react-native-auth-client/api-reference
- Examples: https://rahulunni73.github.io/react-native-auth-client/examples

---

## Testing Locally (Optional)

To preview the site locally before deploying:

### Install Ruby and Jekyll

#### macOS
```bash
# Install Ruby (if not already installed)
brew install ruby

# Add Ruby to PATH (add to ~/.zshrc or ~/.bash_profile)
export PATH="/usr/local/opt/ruby/bin:$PATH"

# Install Bundler
gem install bundler
```

#### Linux
```bash
sudo apt-get install ruby-full build-essential
gem install bundler
```

#### Windows
Download and install Ruby from: https://rubyinstaller.org/

### Install Dependencies and Serve

```bash
# Navigate to docs directory
cd docs

# Install Jekyll and dependencies
bundle install

# Serve the site locally
bundle exec jekyll serve

# Or serve with live reload
bundle exec jekyll serve --livereload
```

The site will be available at: http://localhost:4000/react-native-auth-client/

---

## Updating Documentation

### Automatic Updates

Any push to the `main` branch will automatically trigger a new deployment. The workflow runs on:
- Push to `main` branch
- Manual trigger via Actions tab

### Update Process

1. **Edit documentation files** in the `docs/` folder
2. **Commit and push** changes:
   ```bash
   git add docs/
   git commit -m "docs: Update documentation"
   git push origin main
   ```
3. **Wait for automatic deployment** (3-5 minutes)
4. **Verify changes** at your GitHub Pages URL

---

## Customization Options

### Change Theme

Edit `docs/_config.yml`:

```yaml
# Change from cayman to another theme
theme: jekyll-theme-minimal
# or
theme: jekyll-theme-slate
# or
theme: jekyll-theme-architect
```

### Update Site Colors

Edit `docs/assets/css/style.scss` and modify the header gradient:

```scss
.page-header {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  /* Change to your preferred colors */
}
```

### Add New Pages

1. Create a new `.md` file in `docs/`
2. Add front matter:
   ```yaml
   ---
   layout: default
   title: Your Page Title
   description: Page description
   ---
   ```
3. Add content in Markdown
4. Update navigation in `docs/_config.yml`:
   ```yaml
   nav_links:
     - title: Your Page
       url: /your-page
   ```

### Add Analytics

Edit `docs/_config.yml` and add your Google Analytics tracking ID:

```yaml
google_analytics: G-XXXXXXXXXX
```

---

## Troubleshooting

### Build Fails

**Check the Actions log:**
1. Go to Actions tab
2. Click on the failed workflow run
3. Review the error messages

**Common issues:**
- **YAML syntax errors**: Validate your `_config.yml` with a YAML validator
- **Markdown errors**: Check your `.md` files for syntax issues
- **Missing dependencies**: Ensure `Gemfile` is correct

### Page Not Found (404)

**Possible causes:**
1. **GitHub Pages not enabled**: Check Settings → Pages
2. **Wrong URL**: Use the correct repository name in URL
3. **Deployment not complete**: Wait for the workflow to finish
4. **Branch mismatch**: Ensure you're pushing to `main` branch

### Styles Not Loading

**Fixes:**
1. **Clear browser cache**: Hard refresh with Cmd+Shift+R (Mac) or Ctrl+Shift+R (Windows)
2. **Check baseurl**: Ensure `baseurl` in `_config.yml` matches your repository name
3. **Verify CSS file**: Make sure `docs/assets/css/style.scss` exists

### Local Build Issues

**Bundle install fails:**
```bash
# Update bundler
gem update --system
gem install bundler

# Clean and reinstall
cd docs
rm Gemfile.lock
bundle install
```

**Port already in use:**
```bash
# Use a different port
bundle exec jekyll serve --port 4001
```

---

## Advanced Configuration

### Custom Domain

To use a custom domain (e.g., docs.yourdomain.com):

1. **Add CNAME file** in `docs/` directory:
   ```
   docs.yourdomain.com
   ```

2. **Configure DNS** with your domain provider:
   ```
   Type: CNAME
   Name: docs
   Value: rahulunni73.github.io
   ```

3. **Enable in GitHub**:
   - Settings → Pages → Custom domain
   - Enter: docs.yourdomain.com
   - Check "Enforce HTTPS"

### Add Search Functionality

Add Jekyll search plugin to `docs/_config.yml`:

```yaml
plugins:
  - jekyll-seo-tag
  - jekyll-sitemap
  - jekyll-feed
  - jekyll-lunr-js-search  # Add this
```

Update `docs/Gemfile`:
```ruby
gem "jekyll-lunr-js-search"
```

---

## Maintenance

### Regular Updates

1. **Update Ruby gems** periodically:
   ```bash
   cd docs
   bundle update
   git add Gemfile.lock
   git commit -m "chore: Update Jekyll dependencies"
   git push
   ```

2. **Monitor build status**: Check Actions tab regularly

3. **Review analytics**: Track documentation usage if you added Google Analytics

### Backup

Your documentation is version-controlled in Git, so every change is automatically backed up. You can:
- View history: `git log docs/`
- Restore previous version: `git checkout <commit> -- docs/`
- Create backups: Regular Git pushes ensure cloud backup

---

## Resources

### Jekyll Documentation
- Official site: https://jekyllrb.com/
- Themes: https://jekyllrb.com/docs/themes/
- Plugins: https://jekyllrb.com/docs/plugins/

### GitHub Pages
- Documentation: https://docs.github.com/en/pages
- Custom domains: https://docs.github.com/en/pages/configuring-a-custom-domain-for-your-github-pages-site

### Markdown Guide
- Basic syntax: https://www.markdownguide.org/basic-syntax/
- Extended syntax: https://www.markdownguide.org/extended-syntax/

---

## Next Steps

1. ✅ **Commit and push** all changes to GitHub
2. ✅ **Enable GitHub Pages** in repository settings
3. ✅ **Wait for deployment** (3-5 minutes)
4. ✅ **Visit your documentation** site
5. ✅ **Share the URL** with your users
6. ✅ **Update README.md** to link to the documentation

### Update README.md

Add a link to your documentation in your main README.md:

```markdown
## Documentation

📚 **[View Full Documentation](https://rahulunni73.github.io/react-native-auth-client/)**

Quick links:
- [Getting Started](https://rahulunni73.github.io/react-native-auth-client/documentation)
- [API Reference](https://rahulunni73.github.io/react-native-auth-client/api-reference)
- [Examples](https://rahulunni73.github.io/react-native-auth-client/examples)
```

---

## Support

If you encounter any issues:

1. **Check this guide** for troubleshooting steps
2. **Review GitHub Actions logs** for deployment errors
3. **Verify file structure** matches the layout above
4. **Test locally** before pushing to GitHub
5. **Check Jekyll documentation** for configuration issues

---

**Your documentation site is ready to deploy! 🚀**

Follow the steps above to make it live on GitHub Pages.
