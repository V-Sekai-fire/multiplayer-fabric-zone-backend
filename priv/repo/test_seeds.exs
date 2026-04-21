# SPDX-License-Identifier: MIT
# Copyright (c) 2026 K. S. Ernest (iFire) Lee
# Script for populating the database. You can run it as:
#
#     mix run priv/repo/test_seeds.exs
#
# Also called from the container ENTRYPOINT on every boot; all operations are
# idempotent — existing rows are left untouched.
#
# Passwords are read from ADMIN_PASSWORD / USER_PASSWORD environment variables.
# Run generate-secrets.sh in multiplayer-fabric-hosting/ to populate .env
# before the first `docker compose up`.
alias Uro.Accounts.User
alias Uro.Accounts.UserPrivilegeRuleset
alias Uro.Repo

current_time = DateTime.utc_now()

admin_pw =
  System.get_env("ADMIN_PASSWORD") ||
    :crypto.strong_rand_bytes(24) |> Base.url_encode64(padding: false)

user_pw =
  System.get_env("USER_PASSWORD") ||
    :crypto.strong_rand_bytes(24) |> Base.url_encode64(padding: false)

# Start a single transaction for all database seed operations
Repo.transaction(fn ->
  # Upsert normal user and their privileges
  normal_user =
    User
    |> Repo.get_by(email: "user@example.com")
    |> case do
      nil ->
        IO.puts("Seeds: creating regularuser (USER_PASSWORD env var or random)")

        %User{}
        |> User.admin_changeset(%{
          email: "user@example.com",
          username: "regularuser",
          display_name: "Regular User",
          email_notifications: true,
          password: user_pw,
          password_confirmation: user_pw,
          email_confirmed_at: current_time
        })
        |> User.confirm_email_changeset()
        |> Repo.insert!()

      user ->
        user
        |> User.confirm_email_changeset()
        |> Repo.update!()
    end

  # Ensure normal user privileges exist
  normal_user_privileges_params = %{user_id: normal_user.id}

  UserPrivilegeRuleset
  |> Repo.get_by(user_id: normal_user.id)
  |> case do
    nil ->
      UserPrivilegeRuleset.admin_changeset(%UserPrivilegeRuleset{}, normal_user_privileges_params)
      |> Repo.insert!()

    _existing ->
      :ok
  end

  # Upsert admin user and their privileges
  admin_user =
    User
    |> Repo.get_by(email: "admin@example.com")
    |> case do
      nil ->
        IO.puts("Seeds: creating adminuser (ADMIN_PASSWORD env var or random)")

        %User{}
        |> User.admin_changeset(%{
          email: "admin@example.com",
          username: "adminuser",
          display_name: "Admin User",
          email_notifications: true,
          password: admin_pw,
          password_confirmation: admin_pw,
          email_confirmed_at: current_time
        })
        |> User.confirm_email_changeset()
        |> Repo.insert!()

      user ->
        user
        |> User.confirm_email_changeset()
        |> Repo.update!()
    end

  # Ensure admin user privileges exist with additional permissions
  admin_privileges_params = %{
    user_id: admin_user.id,
    is_admin: true,
    can_upload_avatars: true,
    can_upload_maps: true,
    can_upload_props: true,
    can_upload_shared_files: true
  }

  UserPrivilegeRuleset
  |> Repo.get_by(user_id: admin_user.id)
  |> case do
    nil ->
      %UserPrivilegeRuleset{}
      |> UserPrivilegeRuleset.admin_changeset(admin_privileges_params)
      |> Repo.insert!()

    _existing ->
      :ok
  end
end)
