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

    # 🔍 **1️⃣ Capturar rotação e resolução do vídeo**
    rotation_info = `ffprobe -v error -select_streams v:0 -show_entries stream=side_data_list -of json '#{permanent_path}'`
    rotation_metadata = JSON.parse(rotation_info)["streams"]&.first&.dig("side_data_list") || []

    rotation_angle = rotation_metadata.any? ? rotation_metadata.first["rotation"].to_i : 0

    resolution_info = `ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0:s=x '#{permanent_path}'`
    width, height = resolution_info.strip.split("x").map(&:to_i)

    Rails.logger.info "📏 Dimensões detectadas: #{width}x#{height}, Rotação: #{rotation_angle}º"

    # 🔄 **2️⃣ Ajuste de rotação**
    rotation_filter = case rotation_angle
                      when 90  then "transpose=1"
                      when 180 then "hflip,vflip"
                      when 270 then "transpose=2"
                      else nil
                      end

    # 📏 **3️⃣ Redimensionamento correto**
    # Se o vídeo for maior na largura, ele é horizontal.
    # Se for maior na altura, ele é vertical.
    scale_filter = if width > height
                    "scale=1280:-2"  # Mantém largura fixa e ajusta altura
                  else
                    "scale=-2:1280"  # Mantém altura fixa e ajusta largura
                  end

    # 🔀 **4️⃣ Montagem correta dos filtros**
    filter_string = [rotation_filter, scale_filter].compact.join(",")

    # 🚀 **5️⃣ Comando FFmpeg otimizado**
    ffmpeg_command = <<-CMD
      ffmpeg -i '#{permanent_path}' -vf "#{filter_string}" \
      -c:v libx264 -preset ultrafast -crf 23 -b:v 900k -maxrate 1100k -bufsize 2000k \
      -c:a aac -b:a 64k -ar 32000 -ac 1 -threads 4 '#{output_path}'
    CMD

    Rails.logger.info "🚀 Executando comando: #{ffmpeg_command}"



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
