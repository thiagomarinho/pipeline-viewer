require 'yaml'
require 'json'
require 'sinatra'
require_relative 'model'
require_relative 'drawer'

get '/' do
    erb :index
end

get '/how-to-get-compiled-pipeline' do
    erb :how_to_get_compiled_pipeline
end

post '/preview-pipeline' do
    pipeline = to_model(params['pipeline'])

    current_x = 0
    current_y = 0

    @drawer = Drawer.new(pipeline)

    @stages = @drawer.stages
    @jobs = @drawer.jobs

    @stages_edges = pipeline
        .stages
        .select { |stage| stage.has_dependency? }
        .flat_map { |stage| stage.edge_data }

    @jobs_edges = pipeline
        .jobs
        .select { |job| job.has_dependency? }
        .flat_map { |job| job.edge_data }

    

    erb :read_pipeline
end
