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
    distance_between_blocks = 150
    x_multiplier = 300 # this should be the "stage size", based on the amount of jobs side by side

    {
      data: stage.data,
      position: {
          x: stage.my_index_at_my_level * x_multiplier, # and this is wrong...?
          y: stage.dependency_level * distance_between_blocks # + previous_stage.height?
      }
    }
  end

  def draw_jobs
    @pipeline
      .stages
      .select { |stage| stage.has_jobs? }
      .flat_map { |stage| stage.jobs.map { |job| to_drawing_job(stage, job) } }
  end

  def to_drawing_job(stage, job)
    y_distance_between_blocks = 50
    x_multiplier = 100
    x_my_position = x_multiplier * job.my_index_at_my_level

    x_position_from_parent =  @stages.find { |s| s[:data][:id] == stage.id }[:position][:x]
    y_position_from_parent = @stages.find { |s| s[:data][:id] == stage.id }[:position][:y]

    {
        data: job.data,
        position: {
            x: x_position_from_parent + x_my_position + job.item_size_for_drawing_purposes,
            y: (job.dependency_level * y_distance_between_blocks) + y_position_from_parent
        }
    }
  end
end
