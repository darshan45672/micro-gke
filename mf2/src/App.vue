<script setup lang="ts">
import { ref } from 'vue'
import Card from 'primevue/card'
import Button from 'primevue/button'
import Badge from 'primevue/badge'
import Tag from 'primevue/tag'
import Avatar from 'primevue/avatar'

interface BlogPost {
  id: number
  title: string
  excerpt: string
  author: string
  date: string
  tags: string[]
  readTime: string
  category: string
  severity: 'success' | 'info' | 'warn' | 'danger' | 'secondary' | 'contrast'
}

const navigateToLanding = () => {
  window.location.href = import.meta.env.VITE_LANDING_URL || 'http://localhost:3000'
}

const blogs = ref<BlogPost[]>([
  {
    id: 1,
    title: 'Getting Started with Micro Frontends',
    excerpt: 'Learn how to build scalable applications using micro frontend architecture. This approach allows teams to work independently on different parts of the application.',
    author: 'John Doe',
    date: 'Dec 10, 2024',
    readTime: '8 min read',
    category: 'Architecture',
    severity: 'secondary',
    tags: ['Architecture', 'Frontend', 'Scalability']
  },
  {
    id: 2,
    title: 'Vue.js 3: The Complete Guide',
    excerpt: 'Explore the latest features in Vue.js 3, including the Composition API, improved performance, and better TypeScript support for modern web development.',
    author: 'Jane Smith',
    date: 'Dec 8, 2024',
    readTime: '12 min read',
    category: 'Tutorial',
    severity: 'success',
    tags: ['Vue.js', 'JavaScript', 'Tutorial']
  },
  {
    id: 3,
    title: 'Next.js App Router Deep Dive',
    excerpt: 'Understanding the new App Router in Next.js 13+. Learn about server components, streaming, and how to build faster web applications.',
    author: 'Mike Johnson',
    date: 'Dec 5, 2024',
    readTime: '10 min read',
    category: 'Framework',
    severity: 'info',
    tags: ['Next.js', 'React', 'Performance']
  },
  {
    id: 4,
    title: 'Building Scalable Web Applications',
    excerpt: 'Best practices for building web applications that can scale with your business. From architecture decisions to deployment strategies.',
    author: 'Sarah Williams',
    date: 'Dec 1, 2024',
    readTime: '15 min read',
    category: 'Best Practices',
    severity: 'warn',
    tags: ['Architecture', 'Scalability', 'Best Practices']
  },
  {
    id: 5,
    title: 'TypeScript Tips and Tricks',
    excerpt: 'Advanced TypeScript patterns and techniques that will make your code more maintainable and type-safe. Perfect for intermediate developers.',
    author: 'David Chen',
    date: 'Nov 28, 2024',
    readTime: '7 min read',
    category: 'Programming',
    severity: 'contrast',
    tags: ['TypeScript', 'JavaScript', 'Programming']
  }
])
</script>

<template>
  <div class="app-container">
    <!-- Header -->
    <header class="header">
      <div class="container">
        <div class="header-content">
          <div class="logo-section">
            <i class="pi pi-book" style="font-size: 2.5rem; color: #10b981"></i>
            <div class="title-section">
              <h1 class="title">Tech Blog</h1>
              <p class="subtitle"><i class="pi pi-bolt"></i> Powered by Vue.js • Port 5173</p>
            </div>
          </div>
          <Badge value="Vue.js Micro Frontend" severity="success" size="large"></Badge>
        </div>
      </div>
    </header>

    <!-- Stats -->
    <div class="container stats-section">
      <div class="stats-grid">
        <Card class="stat-card">
          <template #content>
            <div class="stat-content">
              <Avatar icon="pi pi-book" size="large" style="background-color: #8b5cf6; color: white" />
              <div class="stat-text">
                <div class="stat-number">{{ blogs.length }}</div>
                <div class="stat-label">Total Articles</div>
              </div>
            </div>
          </template>
        </Card>
        <Card class="stat-card">
          <template #content>
            <div class="stat-content">
              <Avatar icon="pi pi-tag" size="large" style="background-color: #10b981; color: white" />
              <div class="stat-text">
                <div class="stat-number">3</div>
                <div class="stat-label">Categories</div>
              </div>
            </div>
          </template>
        </Card>
        <Card class="stat-card">
          <template #content>
            <div class="stat-content">
              <Avatar icon="pi pi-clock" size="large" style="background-color: #3b82f6; color: white" />
              <div class="stat-text">
                <div class="stat-number">52</div>
                <div class="stat-label">Min Read Total</div>
              </div>
            </div>
          </template>
        </Card>
      </div>
    </div>

    <!-- Blog Grid -->
    <div class="container">
      <div class="blog-grid">
        <Card v-for="blog in blogs" :key="blog.id" class="blog-card">
          <template #header>
            <div class="card-header-section">
              <Badge :value="blog.category" :severity="blog.severity" />
              <span class="read-time">
                <i class="pi pi-clock"></i>
                {{ blog.readTime }}
              </span>
            </div>
          </template>
          <template #title>
            {{ blog.title }}
          </template>
          <template #subtitle>
            <div class="author-section">
              <Avatar :label="blog.author.charAt(0)" shape="circle" size="large" />
              <div class="author-info">
                <span class="author-name">{{ blog.author }}</span>
                <span class="post-date"><i class="pi pi-calendar"></i> {{ blog.date }}</span>
              </div>
            </div>
          </template>
          <template #content>
            <p class="excerpt">{{ blog.excerpt }}</p>
            <div class="tags">
              <Tag v-for="tag in blog.tags" :key="tag" :value="tag" severity="success" rounded />
            </div>
          </template>
          <template #footer>
            <Button label="Read Article" icon="pi pi-arrow-right" iconPos="right" :severity="blog.severity" class="w-full" />
          </template>
        </Card>
      </div>
    </div>

    <!-- Back Button -->
    <div class="container back-section">
      <Button 
        label="Back to Landing Page"
        icon="pi pi-arrow-left"
        severity="secondary" 
        size="large"
        outlined
        @click="navigateToLanding"
      >
        <template #default>
          <span style="display: flex; align-items: center; gap: 0.5rem;">
            <i class="pi pi-arrow-left"></i>
            <span>Back to Landing Page</span>
            <Badge value="Next.js" severity="info" />
          </span>
        </template>
      </Button>
    </div>
  </div>
</template>

<style scoped>
.app-container {
  min-height: 100vh;
  background: linear-gradient(135deg, #ecfdf5 0%, #d1fae5 50%, #a7f3d0 100%);
  padding-bottom: 4rem;
}

.container {
  max-width: 1280px;
  margin: 0 auto;
  padding: 0 1rem;
}

/* Header */
.header {
  background: rgba(255, 255, 255, 0.95);
  backdrop-filter: blur(10px);
  box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1);
  padding: 2rem 0;
  margin-bottom: 3rem;
  border-bottom: 2px solid #10b981;
}

.header-content {
  display: flex;
  justify-content: space-between;
  align-items: center;
  flex-wrap: wrap;
  gap: 1.5rem;
}

.logo-section {
  display: flex;
  align-items: center;
  gap: 1rem;
}

.title-section {
  display: flex;
  flex-direction: column;
}

.title {
  font-size: 2rem;
  font-weight: 900;
  margin: 0;
  background: linear-gradient(135deg, #10b981 0%, #059669 100%);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
}

.subtitle {
  color: #6b7280;
  font-size: 0.9rem;
  margin: 0.25rem 0 0 0;
  display: flex;
  align-items: center;
  gap: 0.25rem;
}

/* Stats */
.stats-section {
  margin-bottom: 3rem;
}

.stats-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
  gap: 1.5rem;
}

.stat-card {
  transition: transform 0.3s;
}

.stat-card:hover {
  transform: translateY(-4px);
}

.stat-content {
  display: flex;
  align-items: center;
  gap: 1rem;
}

.stat-text {
  flex: 1;
}

.stat-number {
  font-size: 2rem;
  font-weight: 700;
  color: #111827;
}

.stat-label {
  font-size: 0.875rem;
  color: #6b7280;
}

/* Blog Grid */
.blog-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(350px, 1fr));
  gap: 2rem;
  margin-bottom: 3rem;
}

.blog-card {
  transition: all 0.3s;
  height: 100%;
}

.blog-card:hover {
  transform: translateY(-8px);
  box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.15);
}

.card-header-section {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 1rem;
  background: linear-gradient(135deg, rgba(16, 185, 129, 0.1) 0%, rgba(5, 150, 105, 0.05) 100%);
}

.read-time {
  display: flex;
  align-items: center;
  gap: 0.25rem;
  font-size: 0.875rem;
  color: #6b7280;
}

.author-section {
  display: flex;
  align-items: center;
  gap: 1rem;
  margin-top: 0.5rem;
}

.author-info {
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
}

.author-name {
  font-weight: 600;
  color: #374151;
}

.post-date {
  font-size: 0.875rem;
  color: #6b7280;
  display: flex;
  align-items: center;
  gap: 0.25rem;
}

.excerpt {
  color: #6b7280;
  line-height: 1.6;
  margin-bottom: 1rem;
}

.tags {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
}

/* Back Section */
.back-section {
  text-align: center;
  margin-top: 4rem;
}

/* Responsive */
@media (max-width: 768px) {
  .header-content {
    flex-direction: column;
    text-align: center;
  }

  .logo-section {
    flex-direction: column;
  }

  .title {
    font-size: 1.5rem;
  }

  .blog-grid {
    grid-template-columns: 1fr;
  }
}
</style>
