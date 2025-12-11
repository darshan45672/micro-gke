export default function Home() {
  return (
    <div className="flex min-h-screen items-center justify-center bg-gradient-to-br from-blue-50 to-indigo-100 dark:from-gray-900 dark:to-gray-800">
      <main className="flex flex-col items-center justify-center gap-8 p-8 text-center">
        <div className="space-y-4">
          <h1 className="text-5xl font-bold tracking-tight text-gray-900 dark:text-white">
            Welcome to Micro Frontend Demo
          </h1>
          <p className="text-xl text-gray-600 dark:text-gray-300 max-w-2xl">
            This landing page is built with <span className="font-semibold text-blue-600 dark:text-blue-400">Next.js</span>. 
            Click the button below to view our blog listing, which is powered by a separate 
            <span className="font-semibold text-green-600 dark:text-green-400"> Vue.js</span> micro frontend.
          </p>
        </div>
        
        <div className="flex flex-col gap-4 mt-8">
          <a
            href={process.env.NEXT_PUBLIC_BLOG_URL || "http://localhost:5173"}
            target="_blank"
            rel="noopener noreferrer"
            className="px-8 py-4 text-lg font-semibold text-white bg-blue-600 rounded-lg shadow-lg hover:bg-blue-700 transition-all duration-200 hover:shadow-xl hover:scale-105"
          >
            View Blogs →
          </a>
          <p className="text-sm text-gray-500 dark:text-gray-400">
            Opens Vue.js micro frontend
          </p>
        </div>

        <div className="mt-12 p-6 bg-white dark:bg-gray-800 rounded-lg shadow-md max-w-md">
          <h2 className="text-lg font-semibold text-gray-900 dark:text-white mb-3">
            Architecture
          </h2>
          <ul className="text-left text-sm text-gray-600 dark:text-gray-300 space-y-2">
            <li>✅ <strong>Landing Page:</strong> Next.js (Port 3000)</li>
            <li>✅ <strong>Blog Listing:</strong> Vue.js (Port 5173)</li>
            <li>✅ <strong>Pattern:</strong> Independent deployments</li>
            <li>✅ <strong>Communication:</strong> URL navigation</li>
          </ul>
        </div>
      </main>
    </div>
  );
}
