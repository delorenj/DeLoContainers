import React from "react";
import { BookOpen, Code, Layout, Package } from "lucide-react";

const TutorialCard = ({ icon: Icon, title, description }) => (
  <div className="p-6 bg-white rounded-lg shadow-md">
    <div className="flex items-center mb-4">
      <Icon className="w-6 h-6 text-blue-500 mr-3" />
      <h3 className="text-lg font-semibold">{title}</h3>
    </div>
    <p className="text-gray-600">{description}</p>
  </div>
);

const HomePage = () => {
  const tutorials = [
    {
      icon: Layout,
      title: "Project Structure",
      description:
        "Learn how to organize your Next.js project with pages, components, and assets."
    },
    {
      icon: Package,
      title: "Components",
      description:
        "Create reusable 'widgets' that can be used across different pages."
    },
    {
      icon: Code,
      title: "Routing",
      description:
        "Understanding Next.js file-based routing and navigation between pages."
    },
    {
      icon: BookOpen,
      title: "Best Practices",
      description:
        "Learn React and Next.js best practices for clean, maintainable code."
    }
  ];

  return (
    <div className="min-h-screen bg-gray-50">
      <header className="bg-white shadow">
        <div className="max-w-7xl mx-auto py-6 px-4">
          <h1 className="text-3xl font-bold text-gray-900">
            React & Next.js Tutorial
          </h1>
        </div>
      </header>

      <main className="max-w-7xl mx-auto py-6 sm:px-6 lg:px-8">
        <div className="px-4 py-6">
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            {tutorials.map((tutorial, index) => (
              <TutorialCard key={index} {...tutorial} />
            ))}
          </div>
        </div>
      </main>
    </div>
  );
};

export default HomePage;
