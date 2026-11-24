<?php
/*
 * Create the Firefly III owner account from variables before the web server
 * starts (runs from /etc/entrypoint.d after the image's migrations).
 *
 * - No users yet: create the owner exactly like the registration page does
 *   (User::create + the NewUserRegistered event, which gives the first user
 *   the owner role and its own financial administration). From then on
 *   Firefly III's single-user mode keeps the registration page closed.
 * - Owner exists: if RAILWAY_OWNER_MODE is "set" and the password differs
 *   from FIREFLY_OWNER_PASSWORD, update it (the variable is the source of
 *   truth). Mode "lock" never changes an existing password.
 *
 * Exit code 1 only if there are still no users afterwards (fail closed: the
 * registration page must not be served to the first visitor).
 */
declare(strict_types=1);

require '/var/www/html/vendor/autoload.php';
$app = require '/var/www/html/bootstrap/app.php';
$app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();

use FireflyIII\Enums\UserRoleEnum;
use FireflyIII\Events\Security\System\NewUserRegistered;
use FireflyIII\Models\GroupMembership;
use FireflyIII\Models\UserGroup;
use FireflyIII\Models\UserRole;
use FireflyIII\Notifications\Notifiables\OwnerNotifiable;
use FireflyIII\User;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;

function railway_log(string $message): void
{
    fwrite(STDOUT, gmdate('Y-m-d\TH:i:s\Z') . " railway-owner: $message\n");
}

$email    = (string) getenv('RAILWAY_OWNER_EMAIL');
$mode     = (string) getenv('RAILWAY_OWNER_MODE');
$file     = (string) getenv('RAILWAY_OWNER_PASSWORD_FILE');
$given    = '' !== $file && is_readable($file) ? (string) file_get_contents($file) : '';
if ('' !== $file) {
    @unlink($file);
}
$password = 'set' === $mode && '' !== $given ? $given : Str::random(40);
if ('set' === $mode && '' === $given) {
    $mode = 'lock';
}

try {
    if (0 === User::count()) {
        $user = User::create(['email' => $email, 'password' => Hash::make($password)]);
        try {
            event(new NewUserRegistered(new OwnerNotifiable(), $user));
        } catch (Throwable $e) {
            // Notification mails may fail without a mail setup; the role and
            // administration are attached before that in most cases. Check below.
            railway_log('registration event reported: ' . $e->getMessage());
        }
        $user->refresh();
        if (!$user->hasRole('owner')) {
            app(FireflyIII\Repositories\User\UserRepositoryInterface::class)->attachRole($user, 'owner');
        }
        railway_log(sprintf(
            'created owner %s%s',
            $email,
            'set' === $mode ? ' (password from FIREFLY_OWNER_PASSWORD)' : ' with a random password; set FIREFLY_OWNER_PASSWORD (16-128 characters) and redeploy to log in'
        ));
        if (null === $user->user_group_id) {
            // Same steps as HandlesNewUserRegistration::createGroupMembership().
            $group = UserGroup::create(['title' => $email]);
            $role  = UserRole::query()->where('title', UserRoleEnum::OWNER->value)->firstOrFail();
            GroupMembership::create(['user_id' => $user->id, 'user_group_id' => $group->id, 'user_role_id' => $role->id]);
            $user->user_group_id = $group->id;
            $user->save();
            railway_log('created the owner\'s financial administration');
        }
        exit(0);
    }

    if ('set' !== $mode) {
        railway_log('FIREFLY_OWNER_PASSWORD is not valid; no password was changed');
        exit(0);
    }
    /** @var null|User $user */
    $user = User::where('email', $email)->first();
    if (null === $user) {
        railway_log("no user with FIREFLY_OWNER_EMAIL=$email; nothing changed (the email is only used to create the first owner)");
        exit(0);
    }
    if (Hash::check($password, (string) $user->password)) {
        railway_log("password of $email matches FIREFLY_OWNER_PASSWORD");
        exit(0);
    }
    $user->password = Hash::make($password);
    $user->setRememberToken(Str::random(60));
    $user->save();
    railway_log("password of $email changed to FIREFLY_OWNER_PASSWORD");
    exit(0);
} catch (Throwable $e) {
    railway_log('ERROR: ' . $e->getMessage());
    try {
        exit(0 === User::count() ? 1 : 0);
    } catch (Throwable) {
        exit(1);
    }
}
