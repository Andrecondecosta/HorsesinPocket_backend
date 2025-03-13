class Api::V1::VideosCompressController < ApplicationController
  def compress
    if params[:file].present?
      uploaded_file = params[:file]
      temp_path = uploaded_file.path
      permanent_path = Rails.root.join('tmp', "#{SecureRandom.hex}_input.mp4")
      output_path = Rails.root.join('tmp', "#{SecureRandom.hex}_output.mp4")

      # Copiar o arquivo para um local permanente
      Rails.logger.info "Caminho do arquivo temporário: #{temp_path}"
      FileUtils.cp(temp_path, permanent_path)
      Rails.logger.info "Arquivo copiado para: #{permanent_path}"

        # 🔍 **1️⃣ Descobrir rotação e resolução do vídeo**
        rotation_info = `ffprobe -select_streams v:0 -show_entries stream=side_data_list -of json '#{permanent_path}'`
        rotation_metadata = JSON.parse(rotation_info)["streams"]&.first&.dig("side_data_list") || []

        rotation_angle = nil
        rotation_metadata.each do |meta|
          rotation_angle = meta["rotation"].to_i if meta["rotation"]
        end

        resolution_info = `ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0:s=x '#{permanent_path}'`
        width, height = resolution_info.strip.split("x").map(&:to_i)

        Rails.logger.info "Dimensões detectadas: #{width}x#{height}, Rotação: #{rotation_angle}"

        # 🔄 **2️⃣ Aplicar correção de rotação, se necessário**
        rotation_filter = case rotation_angle
                          when 90 then "transpose=1"
                          when 180 then "transpose=2,transpose=2"
                          when 270 then "transpose=2"
                          else nil
                          end

        # 📏 **3️⃣ Mantém a proporção original do vídeo**
        scale_filter = if width > height
                         "scale=1280:-2" # Mantém proporção para vídeos horizontais
                       else
                         "scale=-2:1280" # Mantém proporção para vídeos verticais
                       end

        # 🔀 **4️⃣ Monta os filtros corretamente**
        filter_string = [rotation_filter, scale_filter].compact.join(",")

        # 🏗 **5️⃣ Monta o comando FFmpeg**
        ffmpeg_command = <<-CMD
          ffmpeg -i '#{permanent_path}' -vf "#{filter_string}" \
          -c:v libx264 -preset fast -crf 28 -b:v 800k -maxrate 1000k -bufsize 2000k \
          -c:a aac -b:a 64k -ar 32000 -ac 1 '#{output_path}'
        CMD


      Rails.logger.info "Executando comando: #{ffmpeg_command}"

      begin
        result = nil # Inicializa a variável `result` no escopo correto
        processing_time = Benchmark.realtime do
          result = `#{ffmpeg_command} 2>&1` # Captura a saída do comando
        end
        Rails.logger.info "Tempo de processamento do FFmpeg: #{processing_time.round(2)} segundos"
        Rails.logger.info "Saída do FFmpeg: #{result}"

        # Verificar se o arquivo de saída foi gerado
        if File.exist?(output_path) && File.size(output_path) > 0
          Rails.logger.info "Arquivo comprimido criado em: #{output_path}"
          send_file output_path, type: 'video/mp4', disposition: 'attachment'
        else
          Rails.logger.error "Erro: Arquivo comprimido não foi gerado."
          render json: { error: 'Falha ao comprimir o vídeo.' }, status: :unprocessable_entity
        end
      rescue => e
        Rails.logger.error "Erro ao executar FFmpeg: #{e.message}"
        render json: { error: 'Erro interno ao processar o vídeo.' }, status: :internal_server_error
      end
    else
      Rails.logger.error "Nenhum arquivo foi enviado."
      render json: { error: 'Nenhum arquivo foi enviado.' }, status: :bad_request
    end
  ensure
    # Não excluir os arquivos temporários para depuração
    Rails.logger.info "Arquivos mantidos para análise: #{permanent_path}, #{output_path}"
    # File.delete(permanent_path) if permanent_path && File.exist?(permanent_path)
    # File.delete(output_path) if output_path && File.exist?(output_path)
  end
end
