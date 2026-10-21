class Api::V1::UsersController < ApplicationController
  before_action :authorized # Garante que o usuário está autenticado

  def screenshot_alerts
    # Busca todos os cavalos criados pelo utilizador atual que têm aprovações pendentes
    horse_ids = Horse.where(user_id: current_user.id).pluck(:id)

    pending_by_horse = UserHorse.includes(:user)
                                .where(horse_id: horse_ids, status: 'pending_approval')
                                .where.not(user_id: current_user.id)
                                .group_by(&:horse_id)

    alerts = pending_by_horse.map do |horse_id, user_horses|
      horse = Horse.find_by(id: horse_id)
      next unless horse

      {
        horse_id: horse.id,
        horse_name: horse.name,
        # user_name: quem tirou a captura (o frontend mostra "<nome> took a screenshot")
        alerts: user_horses.map { |uh| { user_horse_id: uh.id, user_name: uh.user&.name&.strip.presence } }
      }
    end.compact

    render json: { screenshot_alerts: alerts }
  end

  def get_user_status
    user = current_user

    render json: {
      plan: current_user.plan,
      used_horses: current_user.used_horses,
      max_horses: current_user.max_horses || 0,
      used_shares: current_user.used_shares,
      max_shares: current_user.max_shares || 0
    }
  end

def destroy_account
  user = current_user
  user_id = user.id

  ActiveRecord::Base.transaction do
    # 1. Delete logs
    logs_deleted = Log.where(user_id: user_id).delete_all
    Rails.logger.info "DELETE ACCOUNT [user:#{user_id}] Logs deleted: #{logs_deleted}"

    screenshots_deleted = ScreenshotEvent.where(user_id: user_id).delete_all
    Rails.logger.info "DELETE ACCOUNT [user:#{user_id}] ScreenshotEvents deleted: #{screenshots_deleted}"

    # 2. Get horse IDs before deleting anything
    horse_ids = user.horses.pluck(:id)
    Rails.logger.info "DELETE ACCOUNT [user:#{user_id}] Horse IDs to delete: #{horse_ids}"

    # 3. Delete ALL user_horses referencing this user's horses (other users received them)
    if horse_ids.any?
      uh_by_horse = UserHorse.unscoped.where(horse_id: horse_ids).delete_all
      Rails.logger.info "DELETE ACCOUNT [user:#{user_id}] UserHorses deleted by horse_id: #{uh_by_horse}"

      sl_deleted = SharedLink.unscoped.where(horse_id: horse_ids).delete_all
      Rails.logger.info "DELETE ACCOUNT [user:#{user_id}] SharedLinks deleted by horse_id: #{sl_deleted}"
    end

    # 4. Delete ALL user_horses where this user is the receiver
    uh_by_user = UserHorse.unscoped.where(user_id: user_id).delete_all
    Rails.logger.info "DELETE ACCOUNT [user:#{user_id}] UserHorses deleted by user_id: #{uh_by_user}"

    # 5. Delete ALL user_horses where this user is the sharer (shared_by)
    if UserHorse.column_names.include?('shared_by')
      uh_by_shared = UserHorse.unscoped.where(shared_by: user_id).delete_all
      Rails.logger.info "DELETE ACCOUNT [user:#{user_id}] UserHorses deleted by shared_by: #{uh_by_shared}"
    end

    # 6. Verification — check if any user_horses still reference this user
    remaining = UserHorse.unscoped.where("user_id = ? OR horse_id IN (?) #{ UserHorse.column_names.include?('shared_by') ? 'OR shared_by = ?' : ''}", user_id, horse_ids.presence || [0], *(UserHorse.column_names.include?('shared_by') ? [user_id] : [])).count
    if remaining > 0
      Rails.logger.error "DELETE ACCOUNT [user:#{user_id}] STILL #{remaining} user_horses referencing this user!"
      raise "Cannot delete user: #{remaining} user_horses still reference user #{user_id}"
    end
    Rails.logger.info "DELETE ACCOUNT [user:#{user_id}] Verification passed: 0 remaining user_horses"

    # 7. Delete horses with destroy to trigger all callbacks and cleanup
    user.horses.each do |horse|
      horse.ancestors.delete_all
      horse.images.purge
      horse.videos.purge
      horse.destroy!
      Rails.logger.info "DELETE ACCOUNT [user:#{user_id}] Horse #{horse.id} destroyed"
    end

    # 8. Final delete of the user
    user.destroy!
    Rails.logger.info "DELETE ACCOUNT [user:#{user_id}] User destroyed successfully"
  end

  render json: { message: "Account deleted successfully" }, status: :ok
rescue => e
  Rails.logger.error "DELETE ACCOUNT ERROR [user:#{user_id}]: #{e.message}"
  render json: { error: "Error deleting account: #{e.message}" }, status: :unprocessable_entity
end
end
