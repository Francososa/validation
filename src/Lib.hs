{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE ApplicativeDo #-}
{-# LANGUAGE OverloadedStrings #-}
module Lib where

import Control.Lens
import Data.Char
import Data.Coerce
import Data.Validation
import Data.Semigroup
import qualified Data.Text as T
import qualified Data.Text.IO as TIO


newtype Password = Password T.Text
  deriving Show


newtype Error = Error T.Text
  deriving Show

instance Semigroup Error where
  Error xs <> Error ys = Error (xs <> (T.pack "\n") <> ys)

toError :: T.Text -> Error
toError input = Error input


newtype Username = Username T.Text
  deriving Show


data User = User Username Password
  deriving Show


type Rule a = (a -> Validation Error a)


checkPasswordLength :: Rule Password
checkPasswordLength (Password password) =
  case (T.length password > 20 || T.length password < 10) of
    True -> Failure (toError "Your password has to be between 10 and 20 characters long")
    False -> Success (Password password)


checkUsernameLength :: T.Text -> Validation Error Username
checkUsernameLength name =
  case (T.length name > 15) of
    True -> Failure (toError "Username cannot be longer than 15 characters.")
    False -> Success (Username name)


checkLength :: Int -> T.Text -> Validation Error T.Text
checkLength n field =
  case (T.length field > n) of
    True -> Failure (toError
                     $ "Fields cannot be longer than "
                     <> (T.pack $ show n)
                     <> " characters")
    False -> Success field


requireAlphaNum :: Rule T.Text
requireAlphaNum xs =
  case (T.all isAlphaNum xs) of
    True -> Success xs
    False -> Failure (toError "Cannot contain whitespace or special characters.")


cleanWhitespace :: Rule T.Text
cleanWhitespace input =
  if T.null (T.strip input)
  then Failure (toError "Cannot be empty")
  else Success $ T.strip input


validatePassword :: Rule Password
validatePassword password =
  case (coerce cleanWhitespace :: Rule Password) password of
    Failure err -> Failure err
    Success password2 ->
      (coerce requireAlphaNum :: Rule Password) password2 *>
                         checkPasswordLength password2


validateUsername :: Rule Username
validateUsername (Username username) =
  case (cleanWhitespace username) of
    Failure err -> Failure err
    Success username2 -> requireAlphaNum username2 *>
                         checkUsernameLength username2


makeUser :: Validate v => Username -> Password -> v Error User
makeUser name pass =
  review _Validation $
  User <$> (usernameErrors name)
       <*> (passwordErrors pass)


makeUserTmpPassword :: Username -> Validation Error User
makeUserTmpPassword name =
  User <$> validateUsername name
       <*> pure (Password "temporaryPassword")


passwordErrors :: Password -> Validation Error Password
passwordErrors password =
  case validatePassword password of
    Failure err -> Failure (toError "Invalid password:"
                            <> err)
    Success password2 -> Success password2


usernameErrors :: Username -> Validation Error Username
usernameErrors username =
  case validateUsername username of
    Failure err -> Failure (toError "Invalid username:"
                            <> err)
    Success username2 -> Success username2


display :: Username -> Password -> IO ()
display name password =
  case makeUser name password of
    Failure err -> TIO.putStrLn (coerce err)
    Success (User (Username name) password) ->
      TIO.putStrLn ("Welcome, " <> name)
