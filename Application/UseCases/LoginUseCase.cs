using Isopoh.Cryptography.Argon2;
using SRJBackend.Application.Interfaces;
using SRJBackend.Domain.Entities;

namespace SRJBackend.Application.UseCases;

public class LoginUseCase
{
    private readonly IAuthRepository _authRepository;
    private readonly IJwtService _jwtService;

    public LoginUseCase(IAuthRepository authRepository, IJwtService jwtService)
    {
        _authRepository = authRepository;
        _jwtService = jwtService;
    }

    public async Task<LoginResult> ExecuteAsync(string email, string password)
    {
        var user = await _authRepository.GetUserByEmailAsync(email);
        if (user == null)
            return LoginResult.Fail("Incorrect Credentials");

        if (user.IsActive != true)
            return LoginResult.Fail("Incorrect Credentials");

        var hashedPassword = await _authRepository.GetHashedPasswordByEmailAsync(email);
        if (hashedPassword == null || !Argon2.Verify(hashedPassword, password))
            return LoginResult.Fail("Incorrect Credentials");

        var token = _jwtService.GenerateToken(user.Id, user.Email!, user.Roles);

        return LoginResult.Ok(token, user);
    }
}
