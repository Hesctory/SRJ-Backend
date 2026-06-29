using Microsoft.AspNetCore.Mvc;
using SRJBackend.Application.Mappers;
using SRJBackend.Application.UseCases;

namespace SRJBackend.Infrastructure.Controllers;

[ApiController]
[Route("api")]
public class UserController : ControllerBase
{
    private readonly LoginUseCase _loginUseCase;

    public UserController(LoginUseCase loginUseCase)
    {
        _loginUseCase = loginUseCase;
    }

    [HttpPost("login")]
    public async Task<IActionResult> Login([FromBody] LoginRequest request)
    {
        var result = await _loginUseCase.ExecuteAsync(request.Email, request.Password);

        return Ok(new
        {
            success = result.Success,
            token = result.Token,
            user = result.User is null ? null : UserMapper.ToDTO(result.User),
            error = result.ErrorMessage
        });
    }
}

public record LoginRequest(string Email, string Password);
