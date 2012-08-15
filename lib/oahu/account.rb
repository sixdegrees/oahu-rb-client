module Oahu
  class Account
    
    attr_reader :id 

    def initialize id
      @id = id
    end

    def event action, data={}, ctx={}
      data['action'] = action
      Oahu.post("/events", { event: { data: data, ctx: ctx } }, request_opts)
    end

    def fetch
      Oahu.get("/me", {}, request_opts)
    end

    def update_player attrs
      Oahu.put("/player", attrs, request_opts)
    end

    def like oid, ctx={}
      event "like", { object_id: oid }, ctx
    end

    protected

    def request_opts
      { auth: ['account', @id, @id] }
    end

  end
end