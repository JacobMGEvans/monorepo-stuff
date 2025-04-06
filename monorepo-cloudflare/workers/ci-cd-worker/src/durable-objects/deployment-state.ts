export class DeploymentState implements DurableObject {
  private state: DurableObjectState;
  private deployments: any = {};

  constructor(state: DurableObjectState) {
    this.state = state;
  }

  async fetch(request: Request): Promise<Response> {
    const url = new URL(request.url);
    const path = url.pathname;

    if (request.method === "POST" && path === "/start-deployment") {
      const data = await request.json();
      const deploymentId = crypto.randomUUID();
      
      this.deployments[deploymentId] = {
        id: deploymentId,
        environment: data.environment,
        packages: data.packages || [],
        status: "deploying",
        startTime: Date.now()
      };
      
      await this.state.storage.put("deployments", this.deployments);
      return new Response(JSON.stringify({ deploymentId }), {
        headers: { "Content-Type": "application/json" }
      });
    }
    
    if (request.method === "POST" && path === "/complete-deployment") {
      const data = await request.json();
      const { deploymentId, success, details } = data;
      
      if (this.deployments[deploymentId]) {
        this.deployments[deploymentId].status = success ? "success" : "failed";
        this.deployments[deploymentId].endTime = Date.now();
        this.deployments[deploymentId].details = details || {};
        
        await this.state.storage.put("deployments", this.deployments);
        return new Response(JSON.stringify({ success: true }), {
          headers: { "Content-Type": "application/json" }
        });
      }
      
      return new Response(JSON.stringify({ error: "Deployment not found" }), {
        status: 404,
        headers: { "Content-Type": "application/json" }
      });
    }
    
    if (request.method === "GET" && path === "/deployments") {
      return new Response(JSON.stringify(this.deployments), {
        headers: { "Content-Type": "application/json" }
      });
    }
    
    if (request.method === "GET" && path.startsWith("/deployment/")) {
      const deploymentId = path.split("/").pop();
      
      if (this.deployments[deploymentId]) {
        return new Response(JSON.stringify(this.deployments[deploymentId]), {
          headers: { "Content-Type": "application/json" }
        });
      }
      
      return new Response(JSON.stringify({ error: "Deployment not found" }), {
        status: 404,
        headers: { "Content-Type": "application/json" }
      });
    }
    
    return new Response("Not found", { status: 404 });
  }
}
