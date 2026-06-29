using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SRJBackend.Application.Interfaces;
using SRJBackend.Infrastructure.Http;

namespace SRJBackend.Infrastructure.Controllers;

[ApiController]
[Route("api/debt-installments")]
public class DebtInstallmentsController : ControllerBase
{
    private readonly IDebtInstallmentQueries _queries;

    public DebtInstallmentsController(IDebtInstallmentQueries queries)
    {
        _queries = queries;
    }

    [HttpGet]
    [Authorize(Policy = "debt-installment.read")]
    public async Task<IActionResult> GetAll(
        [FromQuery] string? filter = null,
        [FromQuery] string? range = null)
    {
        if (filter == null)
            return BadRequest("El parámetro 'filter' con 'debtId' es requerido.");

        var f = ListRequest.ParseFilterDictionary(filter)!;
        if (!f.TryGetValue("debtId", out var debtIdEl) || !debtIdEl.TryGetInt64(out var debtId))
            return BadRequest("El filtro 'debtId' es requerido.");

        var (skip, take) = ListRequest.ParseRange(range);
        var (items, total) = await _queries.GetByDebtAsync(debtId, skip, take);
        Response.SetContentRange("debt-installments", skip, items, total);
        return Ok(items);
    }

    [HttpGet("{id:long}")]
    [Authorize(Policy = "debt-installment.read")]
    public async Task<IActionResult> GetById(long id)
    {
        var item = await _queries.GetByIdAsync(id);
        if (item == null) return NotFound();
        return Ok(item);
    }
}
