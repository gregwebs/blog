---
title: A Gatsby JS blog
date: "2018-01-10T22:12:03.284Z"
---

I decided to start blogging again. I wanted my blog to meet these requirements:

* static site that is easy to host
* easy to get started with
* can be integrated with a headless CMS

GatsbyJS met these requirements. It deploys a SPA (Single Page Application), which may be overkill,
but it has the advantage of being a system that should be easier to draw CMS content from.
Rendering from Javascript means frontend customization is easier.
Additionally, I am familiar with React, so this will hopefully be a productive environment.

For now, I am just going to use markdown posts from the filesystem, but I will be looking at the
CMS integration.

I am using the [standard blog starter](https://github.com/gatsbyjs/gatsby-starter-blog).
I added [Discus](https://github.com/mzabriskie/react-disqus-thread) comments.
There wasn't much else needed after that beyond a few styling fixes.


# Deploy to Netlify

I am deploying to Netlify, which is a service for static sites. I am not using Netlify CMS, etc, but
just giving Netlify the staic build.

I am really happy with Netlify. Deployment is easy, with notifications when complete. They have a lot of conveniences that most sites can benefit from.
For example, clicking a button to get a let's encrypt SSL cert for the site.


## CMS integration

Local filesystem markdown editing can be a poor way of blogging for two reasons.

* slow turn-around to seeing the post in the blog
* requiring running blog software just to write or edit some content

Gatsby solves the first issue with a hot-reload feature. Note that a switch to a CMS can
re-introduce this issue (the Contentful source requires restarting the development server).
Gatsby is not necessarily well designed for dynamic updates, but you can see someone eventually
achieving this [here](https://medium.com/@dwalsh.sdlr/gatsby-apollo-graphcool-netlify-the-webs-promised-land-6dd510efbd72).

One would use a *headless* CMS, which is built around APIs and separation of presentation.
These both have free tiers that probably work for personal sites.
I believe if one only statically builds the site, users of the site would not hit the API. However, if the SPA is shipped, it might actively use the APIs.

* [GraphCMS](https://www.npmjs.com/package/gatsby-source-graphcms)
* [Contentful](http://blog.alexmlewis.com/creating-a-blog-with-gatsbyjs-part-two/) and [here](https://hunterchang.com/gatsby-with-contentful-cms/)
