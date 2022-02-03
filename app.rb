require 'yaml'
require 'json'
require 'sinatra'

get '/' do
    erb :index
end

def id_for(item, parent=nil)
    return "stage_#{item['stage']}" if item['stage']

    return "job_#{parent['stage']}_#{item['job']}" if item['job']

    raise "Item not identified: #{item.inspect}"
end

post '/read-pipeline' do
    pipeline = YAML.load(yaml)

    current_x = 0
    current_y = 0
    @stages = pipeline['stages']
        .map { |stage| {
            data: {
                id: id_for(stage),
                name: stage['stage']
            },
            position: {
                x: (current_x += 75),
                y: (current_y += 100)
            }
        }}

    @jobs = pipeline['stages']
        .select { |stage| stage['jobs'] }
        .flat_map do |stage|
            current_x = 0

            stage['jobs'].map do |job|
                previous_x = current_x
                current_x += (75 + (5 * job['job'].size))

                {
                    data: {
                        id: id_for(job, stage),
                        name: job['job'],
                        parent: id_for(stage)
                    },
                    position: {
                        x: @stages.find { |s| s[:data][:id] == id_for(stage)}[:position][:x] + previous_x,
                        y: @stages.find { |s| s[:data][:id] == id_for(stage)}[:position][:y]
                    }
                }
            end
        end

    @stages_edges = pipeline['stages']
        .select { |stage| stage['dependsOn'] }
        .map { |stage| { data: { id: "#{stage['dependsOn']}_#{stage['stage']}", source: "stage_#{stage['dependsOn']}", target: id_for(stage) } } }

    @jobs_edges = []

    # @jobs_edges = pipeline['stages']
    #     .flat_map { |stage| stage['jobs'] }
    #     .reject { |e| e.to_s.empty? }
    #     .select { |job| job['dependsOn'] }
    #     .map { |job| { data: { id: "#{job['dependsOn']}_#{job['job']}", source: job['dependsOn'], target: id_for(job) } } }

    erb :read_pipeline
end
