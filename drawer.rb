# define nível
# aplica x/y de acordo com nível e com siblings
class Drawer
  attr_reader :stages, :jobs
  def initialize(pipeline)
    @pipeline = pipeline
    @current_y = 0

    @stages = draw_stages
    @jobs = draw_jobs
  end

  private

  def draw_stages
    @pipeline
      .stages
      .map { |stage| to_drawing_stage(stage) }
  end

  def to_drawing_stage(stage)
    distance_between_stages = 200
    x_multiplier = 300 # this should be the "stage size", based on the amount of jobs side by side

    {
      data: stage.data,
      position: {
          x: stage.my_index_at_my_level * x_multiplier, # and this is wrong
          y: stage.dependency_level * distance_between_stages
      }
    }
  end

  def draw_jobs
    @pipeline
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
  end
end

class StageToDraw
end

class JobToDraw
end
