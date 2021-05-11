require 'gpgme'

module ActiveMerchant
  class Crypto
    # ActiveMerchant::Crypto.encrypt_and_sign
    # parameters:
    #   plain_text_io: the plain text to encrypt, as a readable IO object
    #   output_path: the absolute path of the file to write
    #   public_key: the gpg armored public key that we will use to encrypt the plain_text
    #   private_key: the gpg armored private key that we will use to sign the plain_text
    # output:
    #   the path to an armored encrypted file
    def self.encrypt_and_sign(plain_text_io, output_path, public_key, private_key)
      gpg_temp_dir = Dir.mktmpdir
      GPGME::Engine.home_dir = gpg_temp_dir

      public_key_imported = GPGME::Key.import(public_key)
      private_key_imported = GPGME::Key.import(private_key)

      raise ArgumentError.new("Failed to import exactly 1 public key. Check public_key provided.") if public_key_imported.imports.size != 1
      # the private_key contains the public_key as well, so .imports.size contains
      # two elements
      raise ArgumentError.new("Failed to import the private key. Check private_key provided.") if private_key_imported.imports.size != 2

      gpg_public_key = GPGME::Key.get(public_key_imported.imports.first.fingerprint)
      gpg_private_key = GPGME::Key.get(private_key_imported.imports.first.fingerprint)

      crypto = GPGME::Crypto.new
      plain_text_data = GPGME::Data.from_io(plain_text_io)

      begin
        File.open(output_path, 'w+') do |encrypted_file|
          crypto.encrypt(
            plain_text_data,
            recipients: [gpg_public_key.email],
            always_trust: true,
            armor: true,
            sign: true,
            signers: [gpg_private_key.email],
            output: encrypted_file,
          )
        end

        # Return the output_path which ought to contain the encrypted file
        output_path
      ensure
        # remove the temporary directory we created
        begin
          FileUtils.remove_entry_secure gpg_temp_dir
        rescue Errno::ENOENT # rubocop:disable Lint/HandleExceptions
          # ignore
        end
      end
    end

    # ActiveMerchant::Crypto.decrypt_and_verify
    # parameters:
    #   ciphertext_io: the ciphertext to decrypt and verify, as a readable IO object
    #   output_path: the absolute path of the file to write
    #   public_key: the gpg armored public key that we will use to verify the signature with
    #   private_key: the gpg armored private key that we will use to decrypt the ciphertext
    # output:
    #   the path to a file with the plaintext
    def self.decrypt_and_verify(ciphertext_io, output_path, public_key, private_key)
      gpg_temp_dir = Dir.mktmpdir
      GPGME::Engine.home_dir = gpg_temp_dir
      GPGME::Key.import(public_key)
      GPGME::Key.import(private_key)

      crypto = GPGME::Crypto.new
      ciphertext_data = GPGME::Data.from_io(ciphertext_io)

      begin
        File.open(output_path, 'w+') do |plaintext_output|
          crypto.decrypt(
            ciphertext_data,
            output: plaintext_output,
          )
        end

        # Return the output_path which ought to contain the encrypted file
        output_path
      ensure
        # remove the temporary directory we created
        begin
          FileUtils.remove_entry_secure gpg_temp_dir
        rescue Errno::ENOENT # rubocop:disable Lint/HandleExceptions
          # ignore
        end
      end
    end
  end
end
