using SRJBackend.Domain.Exceptions;

namespace SRJBackend.Domain.Entities;

public class DLunch
{
    public int Id { get; private set; }
    public int LunchCategoryId { get; private set; }
    public string LunchName { get; private set; }
    public decimal? CostPrice { get; private set; }
    public decimal? SalePrice { get; private set; }
    public string? Comment { get; private set; }

    public bool IsAssignable => SalePrice.HasValue && SalePrice.Value >= 0;

    public static DLunch Create(int lunchCategoryId, string lunchName, decimal? costPrice, decimal? salePrice, string? comment)
    {
        Validate(lunchCategoryId, lunchName, costPrice, salePrice);
        return new DLunch(0, lunchCategoryId, lunchName, costPrice, salePrice, comment);
    }

    public void Update(int lunchCategoryId, string lunchName, decimal? costPrice, decimal? salePrice, string? comment)
    {
        Validate(lunchCategoryId, lunchName, costPrice, salePrice);
        LunchCategoryId = lunchCategoryId;
        LunchName = lunchName;
        CostPrice = costPrice;
        SalePrice = salePrice;
        Comment = comment;
    }

    internal static DLunch Reconstitute(int id, int lunchCategoryId, string lunchName, decimal? costPrice, decimal? salePrice, string? comment)
        => new(id, lunchCategoryId, lunchName, costPrice, salePrice, comment);

    private static void Validate(int lunchCategoryId, string lunchName, decimal? costPrice, decimal? salePrice)
    {
        if (lunchCategoryId <= 0)
            throw new ArgumentException("La categoría de la lonchera no es válida.");
        if (string.IsNullOrWhiteSpace(lunchName))
            throw new DomainException("El nombre de la lonchera es obligatorio.");
        if (costPrice is < 0)
            throw new DomainException("El precio de costo no puede ser negativo.");
        if (salePrice is < 0)
            throw new DomainException("El precio de venta no puede ser negativo.");
    }

    private DLunch(int id, int lunchCategoryId, string lunchName, decimal? costPrice, decimal? salePrice, string? comment)
    {
        Id = id;
        LunchCategoryId = lunchCategoryId;
        LunchName = lunchName;
        CostPrice = costPrice;
        SalePrice = salePrice;
        Comment = comment;
    }
}
