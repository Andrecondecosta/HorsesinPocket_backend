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

      # Executar o comando FFmpeg
      ffmpeg_command = "ffmpeg -i '#{permanent_path}' -c:v libx264 -crf 30 -preset veryfast -b:v 1000k -maxrate 1200k -bufsize 2000k -vf 'scale=854:480' -c:a aac -b:a 64k -ar 32000 -ac 1 '#{output_path}'"


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
