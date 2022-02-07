require 'yaml'
require 'json'
require 'sinatra'
require_relative 'model_parser'

get '/' do
    erb :index
end

get '/how-to-get-compiled-pipeline' do
    erb :how_to_get_compiled_pipeline
end

post '/read-pipeline' do
    pipeline = to_model(params['pipeline'])

    current_x = 0
    current_y = 0
    @stages = pipeline
        .stages
        .map { |stage| {
            data: stage.data,
            position: {
                x: (current_x += 75),
                y: (current_y += 100)
            }
        }}

    @jobs = pipeline
        .stages
        .select { |stage| stage.has_jobs? }
        .flat_map do |stage|
            current_x = 0

            stage.jobs.map do |job|
                previous_x = current_x
                increment_x_with = job.name ? (5 * job.name.size) : 70
                current_x += (75 + increment_x_with)

                {
                    data: job.data,
                    position: {
                        x: @stages.find { |s| s[:data][:id] == stage.id }[:position][:x] + previous_x,
                        y: @stages.find { |s| s[:data][:id] == stage.id }[:position][:y]
                    }
                }
            end
        end

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
