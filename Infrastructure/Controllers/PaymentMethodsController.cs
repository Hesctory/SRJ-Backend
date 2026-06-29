using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SRJBackend.Application.Interfaces;
using SRJBackend.Infrastructure.Http;

namespace SRJBackend.Infrastructure.Controllers;

[ApiController]
[Route("api/payment-methods")]
public class PaymentMethodsController : ControllerBase
{
    private readonly IPaymentMethodQueries _queries;

    public PaymentMethodsController(IPaymentMethodQueries queries)
    {
        _queries = queries;
    }

    [HttpGet]
    [Authorize(Policy = "payment-method.read")]
    public async Task<IActionResult> GetAll()
    {
        var items = await _queries.GetAllAsync();
        Response.SetContentRange("payment-methods", items);
        return Ok(items);
    }
}
