export class BuildState implements DurableObject {
  private state: DurableObjectState;
  private buildInfo: any = {};

  constructor(state: DurableObjectState) {
    this.state = state;
  }

  async fetch(request: Request): Promise<Response> {
    const url = new URL(request.url);
    const path = url.pathname;

    if (request.method === "POST" && path === "/start-build") {
      const data = await request.json();
      const buildId = crypto.randomUUID();
      
      this.buildInfo[buildId] = {
        id: buildId,
        packageName: data.packageName,
        status: "running",
        startTime: Date.now(),
        dependencies: data.dependencies || []
      };
      
      await this.state.storage.put("builds", this.buildInfo);
      return new Response(JSON.stringify({ buildId }), {
        headers: { "Content-Type": "application/json" }
      });
    }
    
    if (request.method === "POST" && path === "/complete-build") {
      const data = await request.json();
      const { buildId, success, artifacts } = data;
      
      if (this.buildInfo[buildId]) {
        this.buildInfo[buildId].status = success ? "success" : "failed";
        this.buildInfo[buildId].endTime = Date.now();
        this.buildInfo[buildId].artifacts = artifacts || [];
        
        await this.state.storage.put("builds", this.buildInfo);
        return new Response(JSON.stringify({ success: true }), {
          headers: { "Content-Type": "application/json" }
        });
      }
      
      return new Response(JSON.stringify({ error: "Build not found" }), {
        status: 404,
        headers: { "Content-Type": "application/json" }
      });
    }
    
    if (request.method === "GET" && path === "/builds") {
      return new Response(JSON.stringify(this.buildInfo), {
        headers: { "Content-Type": "application/json" }
      });
    }
    
    if (request.method === "GET" && path.startsWith("/build/")) {
      const buildId = path.split("/").pop();
      
      if (this.buildInfo[buildId]) {
        return new Response(JSON.stringify(this.buildInfo[buildId]), {
          headers: { "Content-Type": "application/json" }
        });
      }
      
      return new Response(JSON.stringify({ error: "Build not found" }), {
        status: 404,
        headers: { "Content-Type": "application/json" }
      });
    }
    
    return new Response("Not found", { status: 404 });
  }
}
